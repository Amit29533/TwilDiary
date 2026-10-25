#!/usr/bin/env python3
"""Reject test-only resources from the built shipping app, not just source paths."""
import fnmatch
from pathlib import Path
import sys


FIXTURES = ('catalog-*.json', 'trakt-*.json', 'reference-workspace.json', 'workspace.json', '*-golden.json')


def verify(bundle: Path) -> None:
    if not bundle.is_dir():
        raise ValueError('Release app bundle is missing.')
    leaked = []
    for path in bundle.rglob('*'):
        if ('TwilDiaryTestSupport' in path.name
                or any(fnmatch.fnmatchcase(path.name, pattern) for pattern in FIXTURES)):
            leaked.append(path.relative_to(bundle).as_posix())
    if leaked:
        raise ValueError('Release contains test-only resources: ' + ', '.join(sorted(leaked)))


if __name__ == '__main__':
    try:
        verify(Path(sys.argv[1]))
    except (ValueError, IndexError) as error:
        raise SystemExit(str(error)) from error
    print('Release resource check passed: no test-support bundle or disposable fixture JSON.')
    print('Production demo artwork and attribution resources are retained.')
