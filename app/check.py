"""Offline installation checks: no model call or benchmark request."""
import hashlib
import importlib.metadata
import pathlib
import shutil
import subprocess

for tool in ('claude', 'python', 'git', 'curl', 'jq', 'rg', 'gcc', 'gdb', 'nmap', 'socat'):
    assert shutil.which(tool), f'Missing: {tool}'
subprocess.run(['claude', '--version'], check=True)
print('tsec-benchmark:', importlib.metadata.version('tsec-benchmark'))
print('override sha256:', hashlib.sha256(pathlib.Path('/opt/ctf/prompts/override.md').read_bytes()).hexdigest())
print('Offline checks passed. Model gateway and VPN are not tested.')
