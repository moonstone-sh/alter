"""Run real Alter edits and Ballad orbit exports on a disposable checkout."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tarfile

repo = Path(__file__).resolve().parents[2]
moon = os.environ.get('MOONSTONE_BIN') or shutil.which('moon')
ballad = Path(os.environ.get('BALLAD_SOURCE', repo/'.ci/ballad')).resolve()
valua = Path(os.environ.get('VALUA_SOURCE', repo/'.ci/valua')).resolve()
assert moon and (ballad/'src/main.lua').is_file() and (valua/'src/valua.lua').is_file()
with tempfile.TemporaryDirectory(prefix='alter lifecycle ') as directory:
    root = Path(directory)/'source'
    shutil.copytree(repo, root, ignore=shutil.ignore_patterns('.git', '.ci', '.moonstone', '.ballad', 'dist', 'node_modules'))
    def run(project, *args):
        result = subprocess.run([moon, '-C', str(project), *args], capture_output=True, text=True, timeout=600)
        assert result.returncode == 0, (args, result.stdout, result.stderr)
        print(result.stdout)
    for project in (root, *(root/name for name in ('host','json-backend','toml-backend','jsonc-backend'))):
        run(project, 'remove', 'moonstone/ballad', '--no-sync')
        run(project, 'add', 'path:'+ballad.as_posix(), '--tool', '--no-sync')
        run(project, 'sync')
    paths = valua.as_posix()+'/src/?.lua;'+valua.as_posix()+'/src/?/init.lua;'
    run(root, 'exec', '--', 'lua', '-e', 'package.path=[['+paths+']]..package.path; dofile("test_all.lua")')
    run(root, 'exec', '--', 'ballad', 'play', 'partiture.lua')
    packages = list((root/'dist/orbit').rglob('package.toml'))
    assert len(packages) == 4, packages
    archives = list((root/'dist/orbit').rglob('*.tar.gz'))
    assert len(archives) == 4, archives
    contents = []
    for archive in archives:
        with tarfile.open(archive) as bundle:
            contents.extend(bundle.getnames())
    assert any(name.endswith('alter/file_replace@windows.lua') for name in contents), contents
print('PASS: Alter edits, orbit export, and all four source archives')
