"""Build a byte-exact approved-design / native-production review artifact."""
import argparse
import json
from pathlib import Path
import shutil

from Tools.build_integration_review import FIELDS, build
from Tools.collect_integration_captures import collect

APPROVED_SOURCE = 'e94c2cbb6f6914e0ebb21ded090beaa54013e4df'


def approved_scenes(rows):
    # Keep capture configuration untouched. Do not pretend a text settings rail
    # depicts the native annotation editor or simulated audio proves a microphone.
    names = {
        'Polish-Pen-Context': 'Pen-Tools',
        'Polish-Favorite-Pens': 'Favorite-Pens',
        'Document-PageThumbnails': 'Thumbnails',
        'Audio-SavedPlaybackAndMarkers': 'Recording-Markers',
        'Audio-MarkerSeek-02m18s-Page8': 'Recording-Playback',
        'Polish-Audio-ActiveMarker': 'Recording-Active',
        'Document-Focus': 'Focus',
        'Approval-ExtremeType-English-Dark-Portrait': 'Editor',
        'Approval-ExtremeType-Arabic-Light-Portrait': 'Editor',
    }
    result = []
    for original in rows:
        if original.get('source') != APPROVED_SOURCE:
            continue
        name = original['logical_name']
        scene = names.get(name)
        if name.startswith(('Light-', 'Dark-', 'English-', 'ExtremeType-')):
            parts = name.split('-')
            scene = {'document': 'Editor', 'library': 'Library'}.get(parts[1])
        if name.startswith('Final-'):
            if '-Focus-' in name:
                scene = 'Focus'
            elif '-RestoredSplit-' in name:
                scene = 'Notes-Split'
            elif '-ExpandedNotes-' in name or '-StandaloneNotes-' in name:
                scene = 'Notes-Expanded'
        if name.startswith('Polish-CompactAccessible-DocumentFocus-'):
            scene = 'Focus'
        if scene:
            result.append(dict(original, scene=scene))
    # The approved bundle intentionally retains several shots of one context.
    # Prefer its named final rendering/thumbnail/focus checks, never a different
    # language or device. Unresolved equal-priority duplicates stay ambiguous.
    groups = {}
    for row in result:
        rank = 1
        test = row.get('test', '')
        if test.endswith(('testUpdatedDocumentTextRendering()', 'testPolishPickerUsesRealPageThumbnails()')):
            rank = 2
        if row['scene'] == 'Focus' and row['logical_name'].startswith('Final-'):
            rank = 2
        if row['logical_name'].startswith('Approval-ExtremeType-'):
            rank = 3
        groups.setdefault(tuple(row[field] for field in FIELDS), []).append((rank, row))
    return [row for candidates in groups.values() for rank, row in candidates
            if rank == max(item[0] for item in candidates)]


def production_scenes(root, source, run, jobs, prefix, families=('iPhone', 'iPad')):
    rows = []
    for family in families:
        evidence = root / ('production-captures-' + family)
        proof = json.loads((evidence / 'provenance.json').read_text())
        if proof != dict(source=source, family=family, run=int(run)):
            raise ValueError('Staged production provenance does not match the executing source and run')
        matching = [job for job in jobs if job['name'] == f'{prefix} ({family})'
                    and job['run_id'] == int(run) and job['status'] == 'completed'
                    and job['conclusion'] == 'success']
        if len(matching) != 1:
            raise ValueError('Each device requires its own single passing native job')
        for row in collect(evidence, source, family, run, matching[0]['id']):
            row['file'] = (Path(evidence.name) / row['file']).as_posix()
            rows.append(row)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--captures', type=Path, required=True)
    parser.add_argument('--approved', type=Path, required=True)
    parser.add_argument('--jobs', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--run', type=int, required=True)
    parser.add_argument('--job-prefix', choices=['focused', 'test'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    before = approved_scenes(json.loads((args.approved / 'all-images.json').read_text()))
    if not before:
        raise ValueError('The approved design source is missing')
    after = production_scenes(args.captures, args.source, args.run,
                              json.loads(args.jobs.read_text())['jobs'], args.job_prefix)
    pairs = build(args.approved, before, args.captures, after, args.output)
    archive = shutil.make_archive(str(args.output), 'zip', args.output.parent, args.output.name)
    print(json.dumps(dict(productionCaptures=len(pairs), exactComparisons=sum(p['before'] is not None for p in pairs), archive=archive)))


if __name__ == '__main__':
    main()
