"""Fail closed if the diagnostic ref changes the controlled candidate scope."""
import json
import re
import subprocess
from pathlib import Path

BASE = 'c8903523e8831b24d78e87923ea966408dd5419d'
ROOT = Path(__file__).resolve().parents[1]


def baseline(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)


def verify():
    old = baseline('App/MarginPane.swift')
    addition = '''        // Keep native mode, text and ink elements individually accessible inside
        // one pane boundary, outside the mode-keyed editor host.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("marginPane")
'''
    expected = old.replace('        .id(editor.handwriting)\n', '        .id(editor.handwriting)\n' + addition, 1)
    if (ROOT / 'App/MarginPane.swift').read_text() != expected:
        raise RuntimeError('Unexpected product change beyond the pane AX boundary')

    old = baseline('UITests/LaunchTests.swift')
    new = (ROOT / 'UITests/LaunchTests.swift').read_text()
    start = old.index('    private func marginMountExpectation(')
    end = old.index('    func testMarginHandwritingMountsWithoutTextInteraction', start)
    current_start = new.index('    private func marginMountExpectation(')
    current_end = new.index('    func testMarginHandwritingMountsWithoutTextInteraction', current_start)
    if old[:start] != new[:current_start] or old[end:] != new[current_end:]:
        raise RuntimeError('An original LaunchTests case/helper outside atomic mount changed')
    before = old[start:end]
    after = new[current_start:current_end]
    # Remove only instrumentation and restore the scoped query to its control.
    after = after.replace('        let pane = app.descendants(matching: .any).matching(identifier: "marginPane").element\n', '')
    after = after.replace('let root = try pane.snapshot()', 'let root = try app.snapshot()')
    after = after.replace('return root.identifier == "marginPane" && ', 'return ')
    stronger_global_check = '                // Preserve the global negative domain as an additional query;\n                // this is not a whole-app atomic snapshot equivalence claim.\n                let globalTextQueryStarted = ProcessInfo.processInfo.systemUptime\n                let globalTextAbsent = !app.textViews["splitNotes"].exists\n                let globalTextQueryDuration = ProcessInfo.processInfo.systemUptime - globalTextQueryStarted\n'
    if after.count(stronger_global_check) != 1 or after.count(' && globalTextAbsent') != 1:
        raise RuntimeError('Expected exactly the supplementary global text absence check')
    after = after.replace(stronger_global_check, '')
    after = after.replace(' && globalTextAbsent', '')
    def logic(text):
        return '\n'.join(line for line in text.splitlines()
                         if not line.strip().startswith(('//', 'sample(')))
    if logic(before) != logic(after):
        raise RuntimeError('Atomic mount conditions, traversal, expectation object or logic changed')
    for pattern in [r'func test\w+', r'XCTAssert\w*\(', r'timeout:\s*[\d.]+',
                    r'executionTimeAllowance\s*=\s*\d+', r'.*NSPredicate\(format:.*',
                    r'}, object: [^)]*\)']:
        if re.findall(pattern, old) != re.findall(pattern, new):
            raise RuntimeError('Original case/assertion/deadline/object invariant changed: ' + pattern)
    if len(re.findall(r'^    func test', new, re.M)) != 32:
        raise RuntimeError('Expected all32original LaunchTests methods')
    helper = new[current_start:current_end]
    for marker in ['root.identifier', 'root.elementType.rawValue', 'snapshotDuration=',
                   'nodes=', 'globalTextAbsent=', 'globalTextQueryDuration=', 'pending.append(contentsOf: node.children)',
                   'modeCount == 1 && handwriting && canvasCount > 0 && textCount == 0']:
        if marker not in helper:
            raise RuntimeError('Missing scoped observation invariant: ' + marker)
    if '.firstMatch' in helper:
        raise RuntimeError('Atomic pane selection must remain unique')
    subprocess.run(['git', 'diff', '--exit-code', BASE, '--', 'App',
                    ':(exclude)App/MarginPane.swift', 'Tests', 'project.yml',
                    '.github/workflows/ios-check.yml'], cwd=ROOT, check=True)
    diagnostic = (ROOT / 'UITests/MarginAXScopeDiagnostics.swift').read_text()
    if len(re.findall(r'^    func test', diagnostic, re.M)) != 1:
        raise RuntimeError('Expected one separate structural diagnostic case')
    if '.firstMatch' in diagnostic:
        raise RuntimeError('Structural inspection must not choose a pane with firstMatch')
    print(json.dumps({'baseline': BASE, 'original_ui_cases': 32,
                      'new_structural_ui_cases': 1, 'source_scope_verified': True}))


if __name__ == '__main__':
    verify()
