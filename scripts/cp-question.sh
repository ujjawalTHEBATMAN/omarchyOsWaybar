#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║              CP WORKSPACE LAUNCHER — QUESTION + CONTEST MODE           ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════
QUESTION_BASE="/home/ujjawal/JavaNvimCodes/QuestionSolving"
CONTEST_BASE="/home/ujjawal/JavaNvimCodes/QuestionSolving/Contest"
TEMPLATE_FILE="/home/ujjawal/templates/cp.java" 

PLATFORMS=("Codeforces" "LeetCode" "AtCoder" "CodeChef" "HackerRank")
PLATFORM_ICONS=("🏆" "🧩" "⚡" "🍳" "💚")
PROBLEM_LABELS=("A" "B" "C" "D" "E" "F" "G" "H")

notify() {
    local urgency="${1:-normal}" title="$2" body="$3"
    notify-send -u "$urgency" -a "CP Workspace" -i "code-context" "$title" "$body" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════
# UI Theme Configuration (Premium Rofi Layout)
# ═══════════════════════════════════════════════════════════════════════════
ROFI_THEME=(
    -theme-str 'window { border-radius: 12px; background-color: #1e1e2e; border: 2px; border-color: #89b4fa; padding: 15px; }'
    -theme-str 'mainbox { spacing: 15px; background-color: transparent; }'
    -theme-str 'inputbar { spacing: 10px; background-color: #313244; padding: 10px; border-radius: 8px; text-color: #cdd6f4; }'
    -theme-str 'prompt { text-color: #89b4fa; background-color: transparent; font: "bold"; }'
    -theme-str 'entry { text-color: #cdd6f4; placeholder-color: #a6adc8; background-color: transparent; }'
    -theme-str 'message { padding: 10px; background-color: #313244; border-radius: 8px; }'
    -theme-str 'textbox { text-color: #cdd6f4; background-color: transparent; }'
    -theme-str 'listview { spacing: 8px; border: 0; background-color: transparent; }'
    -theme-str 'element { padding: 12px; border-radius: 8px; background-color: transparent; text-color: #cdd6f4; }'
    -theme-str 'element normal.normal { background-color: transparent; text-color: #cdd6f4; }'
    -theme-str 'element alternate.normal { background-color: transparent; text-color: #cdd6f4; }'
    -theme-str 'element selected.normal { background-color: #89b4fa; text-color: #1e1e2e; }'
    -theme-str 'element-text { background-color: transparent; text-color: inherit; }'
)

# ═══════════════════════════════════════════════════════════════════════════
# Status Mode (Waybar JSON)
# ═══════════════════════════════════════════════════════════════════════════
if [[ "${1:-}" == "--status" ]]; then
    qcount=0; ccount=0
    [[ -d "$QUESTION_BASE" ]] && qcount=$(find "$QUESTION_BASE" -maxdepth 1 -mindepth 1 -type d | wc -l)
    [[ -d "$CONTEST_BASE" ]] && ccount=$(find "$CONTEST_BASE" -maxdepth 1 -mindepth 1 -type d | wc -l)
    echo "{\"text\": \"󰘦\", \"tooltip\": \"CP Workspace Launcher\\n━━━━━━━━━━━━━━━━━━━━━━\\n📁 Questions: ${qcount}\\n🏆 Contests: ${ccount}\\n\\nL-Click → Question Mode\\nR-Click → Contest Mode\", \"class\": \"idle\"}"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# Helper: Generate Solution.java content (with or without method)
# ═══════════════════════════════════════════════════════════════════════════
generate_java() {
    local file="$1" label="$2" has_method="${3:-false}"
    local static_sig="${4:-}" method_name="${5:-}" call_args="${6:-}"
    local return_type="${7:-}" default_return="${8:-}"

    local method_block="" main_call=""

    if [[ "$has_method" == true && -n "$static_sig" ]]; then
        method_block="
  ${static_sig} {

    ${default_return}
  }"
        if [[ "$return_type" == "void" ]]; then
            main_call="    ${method_name}(${call_args});"
        else
            main_call="    ${return_type} result = ${method_name}(${call_args});
    out.println(result);"
        fi
    else
        main_call="
    out.println();"
    fi

    cat > "$file" <<JAVAEOF
import java.io.*;
import java.util.*;

public class Solution {

  static class FastIO {
    BufferedReader br;
    StringTokenizer st;

    FastIO() {
      br = new BufferedReader(new InputStreamReader(System.in));
    }

    String next() {
      while (st == null || !st.hasMoreElements()) {
        try {
          String line = br.readLine();
          if (line == null) return null;
          st = new StringTokenizer(line);
        } catch (IOException e) {
          e.printStackTrace();
        }
      }
      return st.nextToken();
    }

    int nextInt() { return Integer.parseInt(next()); }
    long nextLong() { return Long.parseLong(next()); }
    double nextDouble() { return Double.parseDouble(next()); }

    String nextLine() {
      try { return br.readLine(); }
      catch (IOException e) { e.printStackTrace(); return ""; }
    }

    int[] nextIntArray(int n) {
      int[] a = new int[n];
      for (int i = 0; i < n; i++) a[i] = nextInt();
      return a;
    }

    long[] nextLongArray(int n) {
      long[] a = new long[n];
      for (int i = 0; i < n; i++) a[i] = nextLong();
      return a;
    }

    double[] nextDoubleArray(int n) {
      double[] a = new double[n];
      for (int i = 0; i < n; i++) a[i] = nextDouble();
      return a;
    }

    int[] nextBracketIntArray() {
      String line = nextLine().replaceAll("[\\\\[\\\\]\\\\s]", "");
      if (line.isEmpty()) return new int[0];
      String[] parts = line.split(",");
      int[] a = new int[parts.length];
      for (int i = 0; i < parts.length; i++) a[i] = Integer.parseInt(parts[i]);
      return a;
    }

    long[] nextBracketLongArray() {
      String line = nextLine().replaceAll("[\\\\[\\\\]\\\\s]", "");
      if (line.isEmpty()) return new long[0];
      String[] parts = line.split(",");
      long[] a = new long[parts.length];
      for (int i = 0; i < parts.length; i++) a[i] = Long.parseLong(parts[i]);
      return a;
    }
  }

  static long gcd(long a, long b) { return b == 0 ? a : gcd(b, a % b); }
  static long lcm(long a, long b) { return (a / gcd(a, b)) * b; }

  static boolean isPrime(long n) {
    if (n < 2) return false;
    if (n == 2 || n == 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (long i = 5; i * i <= n; i += 6) if (n % i == 0 || n % (i + 2) == 0) return false;
    return true;
  }

  static long power(long a, long b, long mod) {
    long res = 1; a %= mod;
    while (b > 0) {
      if ((b & 1) == 1) res = (res * a) % mod;
      a = (a * a) % mod; b >>= 1;
    }
    return res;
  }
${method_block}

  public static void main(String[] args) {
    FastIO in = new FastIO();
    PrintWriter out = new PrintWriter(new BufferedOutputStream(System.out));

${main_call}

    out.flush();
  }

  static void printArr(int[] a) {
    StringBuilder sb = new StringBuilder("[");
    for (int i = 0; i < a.length; i++) { if (i > 0) sb.append(", "); sb.append(a[i]); }
    System.out.println(sb.append("]"));
  }

  static void printArr(long[] a) {
    StringBuilder sb = new StringBuilder("[");
    for (int i = 0; i < a.length; i++) { if (i > 0) sb.append(", "); sb.append(a[i]); }
    System.out.println(sb.append("]"));
  }

  static void printArr(double[] a) {
    StringBuilder sb = new StringBuilder("[");
    for (int i = 0; i < a.length; i++) { if (i > 0) sb.append(", "); sb.append(a[i]); }
    System.out.println(sb.append("]"));
  }

  static void printArr(String[] a) { System.out.println(Arrays.toString(a)); }
  static void printArr(boolean[] a) {
    StringBuilder sb = new StringBuilder("[");
    for (int i = 0; i < a.length; i++) { if (i > 0) sb.append(", "); sb.append(a[i]); }
    System.out.println(sb.append("]"));
  }

  static void print2D(int[][] a) { for (int[] r : a) printArr(r); }
  static void print2D(long[][] a) { for (long[] r : a) printArr(r); }
  static <T> void printList(List<T> l) { System.out.println(l); }
  static <T> void printList2D(List<List<T>> l) { for (List<T> r : l) System.out.println(r); }
}
JAVAEOF
}

# ═══════════════════════════════════════════════════════════════════════════
# Helper: Create Excalidraw scaffold
# ═══════════════════════════════════════════════════════════════════════════
create_excalidraw() {
    local file="$1" title="$2"
    cat > "$file" <<EXCEOF
{
  "type": "excalidraw",
  "version": 2,
  "source": "cp-workspace-launcher",
  "elements": [
    {
      "id": "title_text", "type": "text", "x": 100, "y": 50,
      "width": 500, "height": 45,
      "text": "${title}",
      "fontSize": 28, "fontFamily": 1, "textAlign": "left", "verticalAlign": "top",
      "strokeColor": "#1e1e1e", "backgroundColor": "transparent",
      "fillStyle": "solid", "strokeWidth": 1, "roughness": 1, "opacity": 100,
      "angle": 0, "groupIds": [], "boundElements": null,
      "seed": 1234567890, "version": 1, "versionNonce": 1234567890,
      "isDeleted": false, "updated": $(date +%s)000,
      "link": null, "locked": false, "containerId": null,
      "originalText": "${title}", "autoResize": true, "lineHeight": 1.25
    }
  ],
  "appState": { "gridSize": 20, "gridStep": 5, "gridModeEnabled": false, "viewBackgroundColor": "#ffffff" },
  "files": {}
}
EXCEOF
}

# ═══════════════════════════════════════════════════════════════════════════
# CONTEST MODE
# ═══════════════════════════════════════════════════════════════════════════
run_contest_mode() {
    # Step 1: Pick platform
    local platform_menu=""
    for i in "${!PLATFORMS[@]}"; do
        platform_menu+="${PLATFORM_ICONS[$i]}  ${PLATFORMS[$i]}\n"
    done

    local platform_choice
    platform_choice=$(echo -e "$platform_menu" | rofi -dmenu \
        -p " 🏆 Platform " \
        -mesg "  <span color='#89b4fa' size='large'><b>CONTEST SETUP</b></span>\n  Choose the platform for your competitive programming contest." \
        "${ROFI_THEME[@]}" \
        -theme-str 'window { width: 500px; }' \
        -theme-str 'listview { lines: 5; }' \
        -markup-rows \
        2>/dev/null) || exit 0

    local platform_name
    platform_name=$(echo "$platform_choice" | sed 's/^[^ ]* *//')
    local platform_lower
    platform_lower=$(echo "$platform_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

    # Step 2: Contest number
    local contest_input
    contest_input=$(rofi -dmenu \
        -p " 🔢 Contest ID " \
        -mesg "  <span color='#f5c2e7' size='large'><b>ENTER CONTEST NUMBER</b></span>\n  Platform: <b>${platform_name}</b>" \
        "${ROFI_THEME[@]}" \
        -theme-str 'window { width: 500px; }' \
        -theme-str 'listview { enabled: false; }' \
        -theme-str 'entry { placeholder: "e.g. 1950"; }' \
        -lines 0 \
        2>/dev/null) || exit 0

    [[ -z "$contest_input" ]] && exit 0
    local contest_id
    contest_id=$(echo "$contest_input" | sed 's/[^a-zA-Z0-9_-]//g')

    # Step 3: Number of problems
    local num_problems
    num_problems=$(echo -e "4\n5\n6\n7\n8\n3" | awk '{print "  " $1 " Problems"}' | rofi -dmenu \
        -p " 📝 Problems " \
        -mesg "  <span color='#89ca78' size='large'><b>PROBLEM COUNT</b></span>\n  How many problems does this contest have?" \
        "${ROFI_THEME[@]}" \
        -theme-str 'window { width: 450px; }' \
        -theme-str 'listview { lines: 6; }' \
        2>/dev/null) || exit 0

    [[ -z "$num_problems" ]] && exit 0
    num_problems=$(echo "$num_problems" | sed 's/[^0-9]//g')
    [[ -z "$num_problems" ]] && num_problems=4
    (( num_problems > 8 )) && num_problems=8

    # Step 4: Create contest directory
    local contest_dir="${CONTEST_BASE}/${platform_lower}_${contest_id}"

    if [[ -d "$contest_dir" ]]; then
        local action
        action=$(echo -e "📂 Open Existing\n⚠️ Overwrite\n❌ Cancel" | rofi -dmenu \
            -p "  Action " \
            -mesg "  <span color='#f38ba8' size='large'><b>WARNING: FOLDER EXISTS</b></span>\n  Contest folder already exists!\n  <i>${contest_dir}</i>" \
            "${ROFI_THEME[@]}" \
            -theme-str 'window { width: 550px; border-color: #f38ba8; }' \
            -theme-str 'listview { lines: 3; }' \
            -theme-str 'element selected.normal { background-color: #f38ba8; text-color: #1e1e2e; }' \
            -markup-rows \
            2>/dev/null) || exit 0

        case "$action" in
            *Open*)
                kitty --detach --title "Contest ${contest_id}" \
                    nvim "${contest_dir}/A/Solution.java" &
                notify "normal" "📂 Opened Contest" "${platform_name} #${contest_id}"
                exit 0 ;;
            *Overwrite*) rm -rf "$contest_dir" ;;
            *) exit 0 ;;
        esac
    fi

    mkdir -p "$contest_dir"

    # Step 5: Generate problem folders with plain template (no method extraction)
    local files_to_open=()
    for (( i=0; i<num_problems; i++ )); do
        local label="${PROBLEM_LABELS[$i]}"
        local prob_dir="${contest_dir}/${label}"
        mkdir -p "$prob_dir"

        generate_java "${prob_dir}/Solution.java" "$label" false
        files_to_open+=("${prob_dir}/Solution.java")
    done

    create_excalidraw "${contest_dir}/contest.excalidraw" \
        "${platform_name} Contest #${contest_id}"

    # Step 6: Open first problem in Neovim
    kitty --detach --title "Contest ${contest_id} - ${platform_name}" \
        nvim "+normal G" "${files_to_open[0]}" &

    xdg-open "$contest_dir" &

    # Build problem list for notification
    local prob_list=""
    for (( i=0; i<num_problems; i++ )); do
        prob_list+="  ${PROBLEM_LABELS[$i]}/"
    done

    notify "normal" "🏆 Contest Workspace Created!" \
        "${platform_name} #${contest_id}\n\n📁 ${contest_dir}\n📋 Problems:${prob_list}\n\n🚀 Opening Problem A in Neovim"

    echo "✅ Contest workspace: $contest_dir"
}

# ═══════════════════════════════════════════════════════════════════════════
# QUESTION MODE (original flow)
# ═══════════════════════════════════════════════════════════════════════════
run_question_mode() {
    local INPUT
    INPUT=$(rofi -dmenu \
        -p " 🔍 Question " \
        -mesg "  <span color='#89b4fa' size='large'><b>QUESTION DETAILS</b></span>\n  Tip: Copy the LeetCode code block first!\n  <span color='#a6adc8'>Format: 3742. Maximum Path Score</span>" \
        "${ROFI_THEME[@]}" \
        -theme-str 'window { width: 650px; }' \
        -theme-str 'listview { enabled: false; }' \
        -theme-str 'inputbar { children: [prompt, entry]; }' \
        -theme-str 'entry { placeholder: "Paste or type question here..."; }' \
        -lines 0 \
        2>/dev/null) || exit 0

    [[ -z "$INPUT" ]] && exit 0

    local QUESTION_NUM QUESTION_NAME
    if [[ "$INPUT" =~ ^([0-9]+)[^a-zA-Z0-9]*(.*)$ ]]; then
        QUESTION_NUM="${BASH_REMATCH[1]}"
        QUESTION_NAME="${BASH_REMATCH[2]}"
    else
        notify "critical" "❌ Invalid Input" "Could not parse question number and name."
        exit 1
    fi

    [[ -z "$QUESTION_NAME" ]] && { notify "critical" "❌ Invalid Input" "Question name cannot be empty."; exit 1; }

    local SANITIZED_NAME
    SANITIZED_NAME=$(echo "$QUESTION_NAME" | sed 's/[^a-zA-Z0-9_]//g')

    # Auto-read clipboard for method signature
    local CODE_BLOCK=""
    if command -v wl-paste &>/dev/null; then
        CODE_BLOCK=$(wl-paste --no-newline 2>/dev/null || true)
    elif command -v xclip &>/dev/null; then
        CODE_BLOCK=$(xclip -selection clipboard -o 2>/dev/null || true)
    fi

    local PARSED_METHOD="" HAS_METHOD=false
    local STATIC_SIG="" METHOD_NAME="" CALL_ARGS="" RETURN_TYPE="" DEFAULT_RETURN=""

    if [[ -n "$CODE_BLOCK" ]]; then
        PARSED_METHOD=$(python3 -c "
import re, sys
code_block = '''$CODE_BLOCK'''
match = re.search(r'public\s+([\w\[\]<>,\s?]+?)\s+(\w+)\s*\(([^)]*)\)', code_block)
if not match:
    match = re.search(r'([\w\[\]<>,\s?]+?)\s+(\w+)\s*\(([^)]*)\)', code_block)
if not match:
    print('ERROR'); sys.exit(0)
rt = match.group(1).strip()
mn = match.group(2).strip()
pr = match.group(3).strip()
sig = f'public static {rt} {mn}({pr})'
ca = ', '.join(p.strip().split()[-1] for p in pr.split(',') if p.strip()) if pr else ''
rm = {'void':'','int':'return 0;','long':'return 0L;','double':'return 0.0;',
      'boolean':'return false;','String':'return \"\";'}
dr = rm.get(rt, '')
if not dr and rt != 'void':
    if '[]' in rt: dr = f'return new {rt.replace(\"[]\",\"\")}[0];'
    elif rt.startswith('List'): dr = 'return new ArrayList<>();'
    else: dr = 'return null;'
print(f'{sig}\x1f{mn}\x1f{ca}\x1f{rt}\x1f{dr}')
" 2>/dev/null || true)
    fi

    if [[ "$PARSED_METHOD" == "ERROR" || -z "$PARSED_METHOD" ]]; then
        HAS_METHOD=false
        notify "normal" "📋 No method in clipboard" "Using blank template."
    else
        IFS=$'\x1f' read -r STATIC_SIG METHOD_NAME CALL_ARGS RETURN_TYPE DEFAULT_RETURN <<< "$PARSED_METHOD"
        HAS_METHOD=true
        notify "normal" "✅ Method detected" "${STATIC_SIG}"
    fi

    local FOLDER_NAME="q${QUESTION_NUM}_${SANITIZED_NAME}"
    local WORKSPACE_DIR="${QUESTION_BASE}/${FOLDER_NAME}"

    if [[ -d "$WORKSPACE_DIR" ]]; then
        local CHOICE
        CHOICE=$(echo -e "📂 Open Existing\n⚠️ Overwrite\n❌ Cancel" | rofi -dmenu \
            -p "  Action " \
            -mesg "  <span color='#f38ba8' size='large'><b>WARNING: FOLDER EXISTS</b></span>\n  Question folder already exists!\n  <i>${FOLDER_NAME}</i>" \
            "${ROFI_THEME[@]}" \
            -theme-str 'window { width: 550px; border-color: #f38ba8; }' \
            -theme-str 'listview { lines: 3; }' \
            -theme-str 'element selected.normal { background-color: #f38ba8; text-color: #1e1e2e; }' \
            -markup-rows \
            2>/dev/null) || exit 0

        case "$CHOICE" in
            *Open*)
                [[ -f "${WORKSPACE_DIR}/Solution.java" ]] && \
                    kitty --detach --title "Q${QUESTION_NUM} - ${SANITIZED_NAME}" \
                        nvim "${WORKSPACE_DIR}/Solution.java" &
                xdg-open "$WORKSPACE_DIR" &
                notify "normal" "📂 Opened Existing" "Q${QUESTION_NUM}: ${SANITIZED_NAME}"
                exit 0 ;;
            *Overwrite*) rm -rf "$WORKSPACE_DIR" ;;
            *) exit 0 ;;
        esac
    fi

    mkdir -p "$WORKSPACE_DIR"

    generate_java "${WORKSPACE_DIR}/Solution.java" "Q${QUESTION_NUM}" \
        "$HAS_METHOD" "$STATIC_SIG" "$METHOD_NAME" "$CALL_ARGS" "$RETURN_TYPE" "$DEFAULT_RETURN"

    create_excalidraw "${WORKSPACE_DIR}/solution.excalidraw" \
        "Q${QUESTION_NUM}: ${SANITIZED_NAME} — Solution Diagram"

    kitty --detach --title "Q${QUESTION_NUM} - ${SANITIZED_NAME}" \
        nvim "+normal G" "${WORKSPACE_DIR}/Solution.java" &

    xdg-open "$WORKSPACE_DIR" &

    notify "normal" "🚀 CP Workspace Created!" \
        "Q${QUESTION_NUM}: ${SANITIZED_NAME}\n\n📁 ${WORKSPACE_DIR}\n📝 Solution.java → Neovim"
    echo "✅ Workspace created: $WORKSPACE_DIR"
}

# ═══════════════════════════════════════════════════════════════════════════
# ENTRY POINT — Mode Selection
# ═══════════════════════════════════════════════════════════════════════════
if [[ "${1:-}" == "--contest" ]]; then
    run_contest_mode
else
    run_question_mode
fi
