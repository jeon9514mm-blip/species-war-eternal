"""Read-only Android archive validation; does not unpack or modify the APK."""
import json
import struct
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None, 'APK contains a corrupt ZIP entry'
    names=archive.namelist()
    assert 'AndroidManifest.xml' in names and 'classes.dex' in names
    libraries=[name for name in names if name.startswith('lib/') and name.endswith('.so')]
    assert libraries and all(name.startswith('lib/arm64-v8a/') for name in libraries)
    assert 'lib/arm64-v8a/libil2cpp.so' in libraries
    assert 'lib/arm64-v8a/libunity.so' in libraries
    assert any(name.startswith('assets/bin/Data/') for name in names), 'Unity scene data missing'
    assert not any(name.endswith(('.keystore','.jks')) for name in names), 'Private signing key packaged'
    load_alignments={}
    for name in libraries:
        with archive.open(name) as library:
            header=library.read(64)
            assert header[:4]==b'\x7fELF' and header[4]==2 and header[5]==1, name
            assert struct.unpack_from('<H',header,18)[0]==183, name
            offset=struct.unpack_from('<Q',header,32)[0]
            entry_size,count=struct.unpack_from('<HH',header,54)
            library.seek(offset)
            entries=library.read(entry_size*count)
            alignments=[struct.unpack_from('<Q',entries,i*entry_size+48)[0] for i in range(count) if struct.unpack_from('<I',entries,i*entry_size)[0]==1]
            assert alignments and all(alignment>=16384 for alignment in alignments), name+' has a load segment below 16KB alignment'
            load_alignments[name]=alignments
    print(json.dumps({'zip_crc_passed':True,'entry_count':len(names),'arm64_elf_libraries':libraries,'elf_load_alignments':load_alignments,'elf_16kb_alignment_passed':True,'unity_data_present':True,'private_key_absent':True}))
