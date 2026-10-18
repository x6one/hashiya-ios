"""Verify the count-only diagnostic retains the c890 test/product contracts."""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = 'c8903523e8831b24d78e87923ea966408dd5419d'


def baseline(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)


def release(text):
    active = [True]
    result = []
    for line in text.splitlines():
        if line.strip() == '#if DEBUG':
            active.append(False)
        elif line.strip() == '#else':
            active[-1] = not active[-1]
        elif line.strip() == '#endif':
            active.pop()
        elif all(active) and line.strip():
            result.append(line)
    assert len(active) == 1
    return '\n'.join(result)


def verify():
    path = 'UITests/LaunchTests.swift'
    old, new = baseline(path), (ROOT / path).read_text()
    start = old.index('    private func exerciseIndividualInkTargets(')
    end = old.index('    private func marginMountExpectation(', start)
    controlled = old[start:end]
    assert controlled.count('}, object: count)') == 3
    expected = old[:start] + controlled.replace('}, object: count)', '}, object: nil)') + old[end:]
    assert new == expected, 'Unexpected test change beyond three unused count objects'
    assert len(re.findall(r'^    func test', new, re.M)) == 32
    for path in ['App/MarginNotebook.swift', 'App/MarginPane.swift']:
        assert release(baseline(path)) == release((ROOT / path).read_text()), path + ': Release behavior changed'
    notebook = (ROOT / 'App/MarginNotebook.swift').read_text()
    observer = notebook[notebook.index('private struct InkRailObservation:'):notebook.index('// Sheet coordinates')]
    for mutation in [r'\.require\s*\(', r'\.delegate\s*=', r'\.isEnabled\s*=',
                     r'\.isScrollEnabled\s*=', r'\.contentOffset\s*=', r'\.bounces\s*=']:
        assert not re.search(mutation, observer), 'Observer mutates gesture/scroll behavior: ' + mutation
    for marker in ['removeTarget(self', 'accessibilityElementsHidden = true',
                   'samples < 12', 'Self.events < 256']:
        assert marker in observer, 'Missing observer lifecycle/bounds: ' + marker
    subprocess.run(['git', 'diff', '--exit-code', BASE, '--', 'App',
                    ':(exclude)App/MarginNotebook.swift', ':(exclude)App/MarginPane.swift',
                    'Tests', 'project.yml', '.github/workflows/ios-check.yml'], cwd=ROOT, check=True)
    print('Verified: only3count objects differ; all32original cases/conditions/deadlines retained; Release sources equivalent')


if __name__ == '__main__':
    verify()
