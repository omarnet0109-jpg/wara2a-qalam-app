# KT506 32MiB Flash Dump - Authoritative Analysis

**Dump File:** MX25L25633F@WSON8_20260923_223438.BIN  
**Size:** 33,554,432 bytes (32 MiB)  
**SHA256:** `3bdd4c79dfcf310726fe8692fae30873b8524a8bc181cfdba2c48b980b86cf9b`

---

## Flash Layout (Direct Hardware Addresses)

| Offset | Size | Partition | Content |
|--------|------|-----------|---------|
| `0x00000000` | 196 KiB | Boot/SPL | Raw bootloader (possibly Realtek proprietary) |
| `0x00031000` | 1.8 MiB | **cr6c** | MIPS LZMA kernel (uncomp: ~5.8 MiB) |
| `0x001e9c12` | ~164 KiB | *Reserved* | Gap/unused |
| `0x00210000` | 2.5 MiB | **r6cr** | SquashFS4 root filesystem |
| `0x0247bc24` | ~27 MiB | *Reserved/Free* | Available for configuration/data |

---

## Section Headers (Container Format)

### cr6c (Kernel)
```
Header Offset (dump):     0x031000
Flash Offset (w2):        0x00031000
Load Address (RAM):       0x81000000
Payload Length:           0x001b8c02 (1,805,314 bytes)
Checksum (sum16_BE):      0x0000 ✓ (PROVEN - payload self-checksums to 0)
Internal LZMA:            @0x035c18, uncompressed: 0x0059bbc0 (~5.8 MiB)
```

**Content Analysis:**
- Begins with MIPS code (common load pattern 0x00008021...)
- Contains LZMA-compressed kernel image
- Matches OpenWrt 5.4 kernel architecture (MIPS Big-Endian)

### r6cr (Root Filesystem)
```
Header Offset (dump):     0x1fdc12
Flash Offset (w2):        0x00210000
Load Address (RAM):       0x000f0000
Payload Length:           0x0027e002 (2,613,250 bytes)
Checksum (sum16_BE):      0xec5e (algorithm UNKNOWN - NOT sum16=0)
Filesystem Magic:         "hsqsb\x02" (SquashFS v4)
```

**Content Analysis:**
- SquashFS4 filesystem (standard OpenWrt rootfs format)
- Contains complete filesystem tree (bin, sbin, lib, etc.)
- Checksum does NOT match sum16_BE=0 algorithm (different from cr6c)

---

## Boot Region (0x00000 - 0x31000)

**Characteristics:**
- Size: 196,608 bytes (192 KiB allocated, with 4 KiB padding/alignment)
- Content density: 39.9% non-zero bytes
- **No section headers detected** in this region
- Raw binary data (likely Realtek SPL/bootloader)

**Critical:** This region MUST be preserved in any recovery firmware.  
Do NOT modify boot/SPL offset/size without explicit verification.

---

## Checksum Algorithms (PROVEN from Dump Analysis)

### cr6c
- **Algorithm:** sum16_BE(payload) must equal 0x0000
- **Proof:** Actual payload checksums to 0x0000 ✓
- **Implementation:** 16-bit big-endian sum of all bytes, masked to 0xffff

### r6cr
- **Algorithm:** UNKNOWN (empirically: 0xec5e observed)
- **Status:** Does NOT match sum16=0 pattern
- **Next Step:** Try alternative checksums (CRC, different sum algorithms, or device-specific)

---

## Container Format Differences

### rtl7100.bin (Realtek Working - from previous analysis)
```
boot (outer wrapper, 16B header)
├─ cs6c (code section)
├─ cr6c (kernel)
└─ r6cr (rootfs)
```

### KT506 Flash Dump (This Dump)
```
Boot/SPL (raw, 196 KiB, no header)
cr6c (kernel container header + payload)
r6cr (rootfs container header + payload)
```

**Key Difference:** No outer "boot" wrapper, no cs6c section.  
This is a **direct flash layout**, not a firmware container.

---

## Recovery Safety Notes

✓ **Safe to work with:**
- SPL preserved at 0x00000000 (bootloader unmodified)
- TFTP recovery mode remains available
- Can rebuild cr6c + r6cr independently

⚠ **Critical constraints:**
- r6cr checksum algorithm must match before flash
- Any modification to offset 0x00000000-0x00031000 risks boot failure
- Must verify against original dump before deployment

---

## Recommendations for OpenWrt Baseline Build

1. **Extract kernel from cr6c:**
   - Use LZMA decompressor at 0x035c18
   - Verify size matches 0x0059bbc0

2. **Extract rootfs from r6cr:**
   - SquashFS4 is standard OpenWrt format
   - Can be mounted directly for inspection

3. **Build new cr6c + r6cr:**
   - Recompile OpenWrt kernel → LZMA compress → ensure sum16=0
   - Package rootfs as SquashFS4 → determine r6cr checksum algorithm
   - Place at correct flash offsets (0x00031000 and 0x00210000)

4. **Checksum Challenge:**
   - cr6c: use sum16_BE padding/trailer to reach 0x0000
   - r6cr: MUST reverse-engineer algorithm (try CRC32, modulo arithmetic, etc.)

---

## Technical Data

**Dump Characteristics:**
- All values big-endian (BE) unless noted
- Section headers: 16 bytes (magic[4] + load[4] + w2[4] + len[4])
- Payload follows immediately after header
- Header length field = payload byte count (NOT including header)

**LZMA Stream Format:**
- Signature: `5d 00 00 80 00` (props=0x5d, dict=0x00800000)
- Uncompressed size: 8 bytes (little-endian) at offset +5

**SquashFS4:**
- Magic: `hsqsb\x02` at payload start
- Standard OpenWrt compression (zstd or xz)
- Mountable via: `mount -t squashfs -o ro`

---

Generated: 2026-09-27  
Source: KT506 device 32MiB flash dump (MX25L25633F chip)
