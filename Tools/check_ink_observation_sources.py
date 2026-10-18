"""Reject any diagnostic change beyond four unused expectation objects."""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = 'c8903523e8831b24d78e87923ea966408dd5419d'


def verify():
    path = 'UITests/LaunchTests.swift'
    old = subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)
    new = (ROOT / path).read_text()
    start = old.index('    private func exerciseIndividualInkTargets(')
    end = old.index('    private func marginMountExpectation(', start)
    controlled = old[start:end]
    assert controlled.count('}, object: count)') == 3
    assert controlled.count('}, object: picker)') == 1
    expected = old[:start] + controlled.replace('}, object: count)', '}, object: nil)').replace('}, object: picker)', '}, object: nil)') + old[end:]
    assert new == expected, 'Unexpected test input, condition, assertion or deadline change'
    assert len(re.findall(r'^    func test', new, re.M)) == 32
    subprocess.run(['git', 'diff', '--exit-code', BASE, '--', 'App', 'Tests',
                    'UITests', ':(exclude)UITests/LaunchTests.swift',
                    'Tools', ':(exclude)Tools/check_ink_observation_sources.py',
                    'project.yml', '.github/workflows/ios-check.yml',
                    '.github/workflows/office-engine-spike.yml', '.maestro'], cwd=ROOT, check=True)
    print('Verified: four unused objects only; all32 cases and complete application unchanged')


if __name__ == '__main__':
    verify()
