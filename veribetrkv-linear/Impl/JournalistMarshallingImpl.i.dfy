// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "../ByteBlockCacheSystem/JournalBytes.i.dfy"
include "../BlockCacheSystem/DiskLayout.i.dfy"
include "JournalistMarshallingModel.i.dfy"
include "../lib/Lang/System/NativeArrays.s.dfy"
include "../lib/Checksums/CRC32CArrayImpl.i.dfy"
include "../lib/Lang/LinearSequence.i.dfy"

module JournalistMarshallingImpl {
  import opened JournalRanges`Internal
  import opened JournalBytes
  import opened Journal
  import opened DiskLayout
  import opened NativeTypes
  import opened Options
  import opened Sequences
  import opened NativePackedInts
  import opened PackedIntsLib
  import opened LinearSequence_s
  import opened LinearSequence_i
  import NativeArrays
  import CRC32_C_Array_Impl

  import JournalistMarshallingModel

  ///// Marshalling

  method Splice(buf: array<byte>, start: uint64, ins: seq<byte>)
  requires |ins| < 0x1_0000_0000_0000_0000
  requires buf.Length < 0x1_0000_0000_0000_0000
  requires 0 <= start
  requires start as int + |ins| <= buf.Length
  modifies buf
  ensures buf[..] == JournalistMarshallingModel.splice(
      old(buf[..]), start, ins);
  {
    JournalistMarshallingModel.reveal_splice();
    NativeArrays.CopySeqIntoArray(ins, 0, buf, start,
        |ins| as uint64);
  }

  method WriteOnto(buf: array<byte>, numBlocks: uint64, start: uint64, bytes: seq<byte>)
  requires buf.Length == 4096 * numBlocks as int
  requires numBlocks <= NumJournalBlocks()
  requires |bytes| <= 4064
  requires 0 <= start as int <= start as int + |bytes| <= 4064 * numBlocks as int
  modifies buf
  ensures buf[..] == JournalistMarshallingModel.writeOnto(
      old(buf[..]), numBlocks, start, bytes)
  {
    JournalistMarshallingModel.reveal_writeOnto();
    
    if |bytes| as uint64 > 0 {
      var block: uint64 := start / 4064;
      var idx: uint64 := start % 4064;
      if idx + |bytes| as uint64 <= 4064 {
        Splice(buf, block * 4096 + 32 + idx, bytes);
      } else {
        Splice(buf, block * 4096 + 32 + idx, bytes[.. 4064 - idx]);
        Splice(buf, (block + 1) * 4096 + 32, bytes[4064 - idx ..]);
      }
    }
  }

  method WriteIntOnto(buf: array<byte>, numBlocks: uint64, start: uint64, val: uint32)
  requires buf.Length == 4096 * numBlocks as int
  requires numBlocks <= NumJournalBlocks()
  requires 0 <= start
  requires start as int + 4 <= numBlocks as int * 4064
  modifies buf
  ensures buf[..] == JournalistMarshallingModel.writeIntOnto(
      old(buf[..]), numBlocks, start, val)
  {
    JournalistMarshallingModel.reveal_writeIntOnto();
    WriteOnto(buf, numBlocks, start,
        pack_LittleEndian_Uint32(val));
  }

  method WriteHeader(buf: array<byte>, numBlocks: uint64, len: uint64)
  requires buf.Length == 4096 * numBlocks as int
  requires 1 <= numBlocks <= NumJournalBlocks()
  requires len <= 0xffff_ffff
  modifies buf
  ensures buf[..] == JournalistMarshallingModel.writeHeader(
      old(buf[..]), numBlocks, len)
  {
    WriteIntOnto(buf, numBlocks, 0, len as uint32);
    WriteIntOnto(buf, numBlocks, 4, numBlocks as uint32);
  }

  method WriteJournalEntries(
      buf: array<byte>, numBlocks: uint64, idx: uint64,
      shared entries: seq<JournalEntry>, start: uint64, len: uint64)
  requires buf.Length == 4096 * numBlocks as int
  requires numBlocks <= NumJournalBlocks()
  requires 0 <= start as int < |entries|
  requires 0 <= len as int <= |entries|
  requires |entries| < 0xfff_ffff_ffff_ffff
  requires idx as int + SumJournalEntries(JournalistMarshallingModel.cyclicSlice(entries[..], start, len)) <= 4064 * numBlocks as int
  modifies buf
  decreases len
  ensures buf[..] == JournalistMarshallingModel.writeJournalEntries(
      old(buf[..]), numBlocks, idx, entries[..], start, len)
  {
    JournalistMarshallingModel.reveal_writeJournalEntries();
    if len != 0 {
      var start' := if start+1 == seq_length(entries) then 0 else start+1;
      JournalistMarshallingModel.
          lemma_cyclicRange_popFront_Sum(entries[..], start, len);
     
      var entry := seq_get(entries, start);
      WriteIntOnto(buf, numBlocks, idx, |entry.key| as uint32);
      var idx1 := idx + 4;
      WriteOnto(buf, numBlocks, idx1, entry.key);
      var idx2 := idx1 + |entry.key| as uint64;
      WriteIntOnto(buf, numBlocks, idx2, |entry.value| as uint32);
      var idx3 := idx2 + 4;
      WriteOnto(buf, numBlocks, idx3, entry.value);
      var idx4 := idx3 + |entry.value| as uint64;
      WriteJournalEntries(buf, numBlocks, idx4, entries, start', len - 1);
    }
  }

  method FillInChecksums(buf: array<byte>, numBlocks: uint64, i: uint64)
  requires buf.Length == numBlocks as int * 4096
  requires numBlocks <= NumJournalBlocks()
  requires 0 <= i <= numBlocks
  modifies buf
  decreases numBlocks - i
  ensures buf[..] == JournalistMarshallingModel.fillInChecksums(
      old(buf[..]), numBlocks, i)
  {
    JournalistMarshallingModel.reveal_fillInChecksums();
    if i != numBlocks {
      var c := CRC32_C_Array_Impl.compute_crc32c_padded(buf, 4096*i as uint32 + 32, 4064);
      NativeArrays.CopySeqIntoArray(c, 0, buf, 4096*i, 32);
      assert buf[..] == JournalistMarshallingModel.splice(
          old(buf[..]), 4096*i, c) by {
        JournalistMarshallingModel.reveal_splice();
      }
      FillInChecksums(buf, numBlocks, i+1);
    }
  }

  method MarshallJournalEntries(
      shared entries: seq<JournalEntry>,
      start: uint64, len: uint64, numBlocks: uint64)
  returns (res: seq<byte>)
  requires 0 <= start as int < |entries|
  requires 0 <= len as int <= |entries|
  requires |entries| <= 0xffff_ffff
  requires WeightJournalEntries(JournalistMarshallingModel.cyclicSlice(entries[..], start, len)) <= 4064 * numBlocks as int
  requires 1 <= numBlocks <= NumJournalBlocks()

  ensures res == JournalistMarshallingModel.marshallJournalEntries(
      entries, start, len, numBlocks)
  {
    reveal_WeightJournalEntries();
    JournalistMarshallingModel.reveal_marshallJournalEntries();

    var buf := NativeArrays.newArrayFill(numBlocks * 4096, 0);
    assert buf[..] == fill((numBlocks * 4096) as int, 0);
    WriteHeader(buf, numBlocks, len);
    WriteJournalEntries(buf, numBlocks, 8, entries, start, len);
    FillInChecksums(buf, numBlocks, 0);

    return buf[..];
  }

}
