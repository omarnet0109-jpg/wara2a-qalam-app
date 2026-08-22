import hashlib
from pathlib import Path

p = Path('windows-builder/final_clean.b64.1')
s = p.read_text(encoding='utf-8').strip()
expected = 'dc74759661b2f14769f244a5068432e8720578f73c542a997694932fadce462b'
if len(s) == 5999:
    chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    result = None
    for i in range(6000):
        for ch in chars:
            candidate = s[:i] + ch + s[i:]
            if hashlib.sha256(candidate.encode()).hexdigest() == expected:
                result = candidate
                break
        if result is not None:
            break
    if result is None:
        raise SystemExit('Unable to repair chunk')
    s = result
if len(s) != 6000 or hashlib.sha256(s.encode()).hexdigest() != expected:
    raise SystemExit('Chunk verification failed')
p.write_text(s, encoding='utf-8')
print('CHUNK_1_OK', len(s))
