// Background UI Automation helper. Compiled on demand by uia.ps1 (uses the .NET Framework csc
// that ships with Windows). A compiled exe is needed because inside Windows PowerShell the
// managed UIA client cannot load the Win32 control proxies (Edit/Button/CheckBox all show up
// as bare "Pane" with no patterns).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Automation;

static class Uia {
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] static extern IntPtr GetL(IntPtr h, int i);
  [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] static extern IntPtr SetL(IntPtr h, int i, IntPtr v);
  [DllImport("user32.dll")] static extern bool SetLayeredWindowAttributes(IntPtr h, uint k, byte a, uint f);
  [DllImport("user32.dll")] static extern bool GetLayeredWindowAttributes(IntPtr h, out uint k, out byte a, out uint f);
  [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);

  static Dictionary<string, string> A = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

  static string Arg(string k) { string v; return A.TryGetValue(k, out v) ? v : null; }
  static bool Has(string k) { return A.ContainsKey(k); }

  static bool Like(string s, string pattern) {
    if (pattern == null) return true;
    s = s ?? "";
    string rx = "^" + Regex.Escape(pattern).Replace("\\*", ".*").Replace("\\?", ".") + "$";
    return Regex.IsMatch(s, rx, RegexOptions.IgnoreCase);
  }
  static string ProcName(int pid) { try { return Process.GetProcessById(pid).ProcessName; } catch { return "?"; } }
  static string TypeName(AutomationElement e) { return e.Current.ControlType.ProgrammaticName.Replace("ControlType.", ""); }
  static string Patterns(AutomationElement e) {
    var l = new List<string>();
    foreach (var p in e.GetSupportedPatterns()) l.Add(p.ProgrammaticName.Replace("PatternIdentifiers.Pattern", "").Replace("Identifiers.Pattern", ""));
    return string.Join(",", l.ToArray());
  }
  static string J(string s) {
    if (s == null) return "null";
    var sb = new StringBuilder("\"");
    foreach (char c in s) {
      if (c == '"') sb.Append("\\\""); else if (c == '\\') sb.Append("\\\\");
      else if (c == '\n') sb.Append("\\n"); else if (c == '\r') sb.Append("\\r"); else if (c == '\t') sb.Append("\\t");
      else if (c < 0x20) sb.AppendFormat("\\u{0:x4}", (int)c); else sb.Append(c);
    }
    return sb.Append('"').ToString();
  }

  static IntPtr oldEx, fg; static bool hadL, hadA; static uint lk, lf; static byte la;
  static void HideRestore(IntPtr h) {
    fg = GetForegroundWindow(); oldEx = GetL(h, -20); hadL = (oldEx.ToInt64() & 0x80000) != 0;
    if (hadL) hadA = GetLayeredWindowAttributes(h, out lk, out la, out lf);
    SetL(h, -20, new IntPtr(oldEx.ToInt64() | 0x80000)); SetLayeredWindowAttributes(h, 0, 0, 2);
    int one = 1; DwmSetWindowAttribute(h, 3, ref one, 4);
    ShowWindow(h, 4); // SW_SHOWNOACTIVATE (fully transparent, so invisible)
  }
  static void Reminimize(IntPtr h) {
    ShowWindow(h, 7); Thread.Sleep(50); // SW_SHOWMINNOACTIVE
    if (hadL && hadA) SetLayeredWindowAttributes(h, lk, la, lf);
    SetL(h, -20, oldEx); int zero = 0; DwmSetWindowAttribute(h, 3, ref zero, 4);
    if (fg != IntPtr.Zero && GetForegroundWindow() != fg) SetForegroundWindow(fg);
  }

  static object Pat(AutomationElement e, AutomationPattern p) {
    object o; return e.TryGetCurrentPattern(p, out o) ? o : null;
  }

  static int Main(string[] argv) {
    Console.OutputEncoding = Encoding.UTF8;
    for (int i = 0; i < argv.Length; i++) {
      if (!argv[i].StartsWith("--")) continue;
      string k = argv[i].Substring(2);
      string v = (i + 1 < argv.Length && !argv[i + 1].StartsWith("--")) ? argv[++i] : "";
      A[k] = v;
    }
    try { return Run(); }
    catch (Exception ex) { Console.Error.WriteLine("error: " + ex.Message); return 1; }
  }

  static int Run() {
    AutomationElement win = null;
    if (Has("hwnd")) {
      string s = Arg("hwnd");
      long v = s.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? Convert.ToInt64(s.Substring(2), 16) : long.Parse(s);
      win = AutomationElement.FromHandle(new IntPtr(v));
    } else {
      if (!Has("pid") && !Has("process") && !Has("title")) throw new Exception("specify --hwnd, --pid, --process or --title");
      foreach (AutomationElement w in AutomationElement.RootElement.FindAll(TreeScope.Children, Condition.TrueCondition)) {
        var c = w.Current;
        if (Has("pid") && c.ProcessId != int.Parse(Arg("pid"))) continue;
        if (Has("process") && !Like(ProcName(c.ProcessId), Regex.Replace(Arg("process"), "\\.exe$", "", RegexOptions.IgnoreCase))) continue;
        if (Has("title") && (c.Name ?? "").IndexOf(Arg("title"), StringComparison.OrdinalIgnoreCase) < 0) continue;
        win = w; break;
      }
    }
    if (win == null) throw new Exception("no matching window (capture-window.ps1 -List shows windows)");

    IntPtr h = new IntPtr(win.Current.NativeWindowHandle);
    bool restored = false;
    if (h != IntPtr.Zero && IsIconic(h) && !Has("no-restore-minimized")) {
      HideRestore(h); restored = true; Thread.Sleep(300);
      win = AutomationElement.FromHandle(h);
    }
    try { return Act(win); }
    finally { if (restored) Reminimize(h); }
  }

  static int Act(AutomationElement win) {
    if (Has("tree")) {
      int maxDepth = Has("depth") ? int.Parse(Arg("depth")) : 8, max = Has("max") ? int.Parse(Arg("max")) : 300, n = 0;
      var walker = TreeWalker.ControlViewWalker;
      var st = new Stack<KeyValuePair<AutomationElement, int>>();
      st.Push(new KeyValuePair<AutomationElement, int>(win, 0));
      while (st.Count > 0 && n < max) {
        var it = st.Pop(); var e = it.Key; int d = it.Value;
        try {
          var c = e.Current;
          Console.WriteLine(new string(' ', d * 2) + "[" + TypeName(e) + "] name='" + c.Name + "' id='" + c.AutomationId +
            "' class='" + c.ClassName + "'" + (c.IsEnabled ? "" : " (disabled)") + (c.IsOffscreen ? " (offscreen)" : "") + " {" + Patterns(e) + "}");
          n++;
        } catch { continue; }
        if (d >= maxDepth) continue;
        var kids = new List<AutomationElement>();
        for (var ch = walker.GetFirstChild(e); ch != null; ch = walker.GetNextSibling(ch)) kids.Add(ch);
        for (int i = kids.Count - 1; i >= 0; i--) st.Push(new KeyValuePair<AutomationElement, int>(kids[i], d + 1));
      }
      if (n >= max) Console.WriteLine("... truncated at " + max + " elements (use -Max / -Depth)");
      return 0;
    }

    if (!Has("name") && !Has("id") && !Has("type") && !Has("class")) throw new Exception("specify -Tree, or -Name / -AutomationId / -ControlType / -ClassName");
    var found = new List<AutomationElement>();
    foreach (AutomationElement e in win.FindAll(TreeScope.Descendants, Condition.TrueCondition)) {
      try {
        var c = e.Current;
        if (Has("name") && !Like(c.Name, Arg("name"))) continue;
        if (Has("id") && c.AutomationId != Arg("id")) continue;
        if (Has("type") && !string.Equals(TypeName(e), Arg("type"), StringComparison.OrdinalIgnoreCase)) continue;
        if (Has("class") && !Like(c.ClassName, Arg("class"))) continue;
        found.Add(e);
      } catch { }
    }
    int idx = Has("index") ? int.Parse(Arg("index")) : 0;
    if (found.Count <= idx) throw new Exception("control not found (" + found.Count + " matches); use -Tree to inspect");
    var el = found[idx];
    var done = new List<string>();

    if (Has("invoke")) {
      var ip = Pat(el, InvokePattern.Pattern) as InvokePattern;
      var tp = Pat(el, TogglePattern.Pattern) as TogglePattern;
      var sp = Pat(el, SelectionItemPattern.Pattern) as SelectionItemPattern;
      var ep = Pat(el, ExpandCollapsePattern.Pattern) as ExpandCollapsePattern;
      if (ip != null) { ip.Invoke(); done.Add("invoke"); }
      else if (tp != null) { tp.Toggle(); done.Add("toggle(fallback)"); }
      else if (sp != null) { sp.Select(); done.Add("select(fallback)"); }
      else if (ep != null) { ep.Expand(); done.Add("expand(fallback)"); }
      else throw new Exception("element supports none of Invoke/Toggle/SelectionItem/ExpandCollapse: {" + Patterns(el) + "}");
    }
    if (Has("set-value")) {
      var vp = Pat(el, ValuePattern.Pattern) as ValuePattern;
      if (vp == null) throw new Exception("element has no ValuePattern: {" + Patterns(el) + "}");
      vp.SetValue(Arg("set-value")); done.Add("setvalue");
    }
    if (Has("toggle")) { var p = Pat(el, TogglePattern.Pattern) as TogglePattern; if (p == null) throw new Exception("no TogglePattern"); p.Toggle(); done.Add("toggle"); }
    if (Has("select")) { var p = Pat(el, SelectionItemPattern.Pattern) as SelectionItemPattern; if (p == null) throw new Exception("no SelectionItemPattern"); p.Select(); done.Add("select"); }
    if (Has("expand")) { var p = Pat(el, ExpandCollapsePattern.Pattern) as ExpandCollapsePattern; if (p == null) throw new Exception("no ExpandCollapsePattern"); p.Expand(); done.Add("expand"); }
    if (Has("collapse")) { var p = Pat(el, ExpandCollapsePattern.Pattern) as ExpandCollapsePattern; if (p == null) throw new Exception("no ExpandCollapsePattern"); p.Collapse(); done.Add("collapse"); }
    if (done.Count > 0) Thread.Sleep(150);

    string text = null;
    if (Has("get-text") || done.Count == 0) {
      var vp = Pat(el, ValuePattern.Pattern) as ValuePattern;
      var tp = Pat(el, TextPattern.Pattern) as TextPattern;
      text = vp != null ? vp.Current.Value : tp != null ? tp.DocumentRange.GetText(100000) : el.Current.Name;
      done.Add("gettext");
    }
    var tg = Pat(el, TogglePattern.Pattern) as TogglePattern;
    var cur = el.Current;
    Console.WriteLine("{\"done\":" + J(string.Join(",", done.ToArray())) +
      ",\"type\":" + J(TypeName(el)) + ",\"name\":" + J(cur.Name) + ",\"automationId\":" + J(cur.AutomationId) +
      ",\"class\":" + J(cur.ClassName) + ",\"patterns\":" + J(Patterns(el)) +
      ",\"text\":" + J(text) + ",\"toggleState\":" + J(tg != null ? tg.Current.ToggleState.ToString() : null) + "}");
    return 0;
  }
}
