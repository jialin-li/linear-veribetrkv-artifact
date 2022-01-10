// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "../lib/Base/DebugAccumulator.i.dfy"
include "../lib/DataStructures/LinearLru.i.dfy"
include "IndirectionTable.i.dfy"
include "StateSectorImpl.i.dfy"
include "BlockAllocatorImpl.i.dfy"
include "CacheImpl.i.dfy"
include "../ByteBlockCacheSystem/AsyncDiskModel.s.dfy"
include "../BlockCacheSystem/BetreeCache.i.dfy"

module StateBCImpl {
  import opened Options
  import opened NativeTypes
  import opened StateSectorImpl
  import opened CacheImpl
  import IT = IndirectionTable
  import opened Bounds
  import opened LinearOption

  import BitmapImpl
  import DebugAccumulator
  import DiskLayout
  import BT = PivotBetreeSpec`Internal
  import BC = BlockCache
  import LinearLru
  import BlockAllocatorImpl
  import D = AsyncDisk
  import BlockAllocatorModel
  import LruModel

  import BBC = BetreeCache

  type ImplVariables = Variables
  type Reference = BT.G.Reference

  predicate WFCache(cache: map<Reference, BT.G.Node>)
  {
    forall ref | ref in cache :: BT.WFNode(cache[ref])
  }

  predicate IsLocAllocOutstanding(outstanding: map<BC.ReqId, BC.OutstandingWrite>, i: int)
  {
    !(forall id | id in outstanding :: outstanding[id].loc.addr as int != i * NodeBlockSize() as int)
  }

  predicate {:opaque} ConsistentBitmapInteral(
      ephemeralIndirectionTable: SectorType.IndirectionTable,
      frozenIndirectionTable: lOption<SectorType.IndirectionTable>,
      persistentIndirectionTable: SectorType.IndirectionTable,
      outstandingBlockWrites: map<BC.ReqId, BC.OutstandingWrite>,
      blockAllocator: BlockAllocatorModel.BlockAllocatorModel)
  {
    && (forall i: int :: ephemeralIndirectionTable.IsLocAllocIndirectionTable(i)
      <==> IT.IndirectionTable.IsLocAllocBitmap(blockAllocator.ephemeral, i))
    && (forall i: int :: persistentIndirectionTable.IsLocAllocIndirectionTable(i)
      <==> IT.IndirectionTable.IsLocAllocBitmap(blockAllocator.persistent, i))
    && (frozenIndirectionTable.lSome? <==> blockAllocator.frozen.Some?)
    && (frozenIndirectionTable.lSome? ==>
      (forall i: int :: frozenIndirectionTable.value.IsLocAllocIndirectionTable(i)
        <==> IT.IndirectionTable.IsLocAllocBitmap(blockAllocator.frozen.value, i)))
    && (forall i: int :: IsLocAllocOutstanding(outstandingBlockWrites, i)
      <==> IT.IndirectionTable.IsLocAllocBitmap(blockAllocator.outstanding, i))
  }

  // TODO rename to like... BlockCache variables or smthn
  linear datatype Variables = 
    | Ready(
        linear persistentIndirectionTable: IT.IndirectionTable, 
        linear frozenIndirectionTable: lOption<IT.IndirectionTable>,
        linear ephemeralIndirectionTable: IT.IndirectionTable,
        persistentIndirectionTableLoc: DiskLayout.Location,
        frozenIndirectionTableLoc: Option<DiskLayout.Location>,
        outstandingIndirectionTableWrite: Option<BC.ReqId>,
        outstandingBlockWrites: map<BC.ReqId, BC.OutstandingWrite>,
        outstandingBlockReads: map<BC.ReqId, BC.OutstandingRead>,
        linear cache: LMutCache,
        linear lru: LinearLru.LinearLru,
        linear blockAllocator: BlockAllocatorImpl.BlockAllocator
      )
    | Loading(
        indirectionTableLoc: DiskLayout.Location,
        indirectionTableRead: Option<BC.ReqId>)
    | Unready
  {
    method DebugAccumulate()
    returns (acc:DebugAccumulator.DebugAccumulator)
    requires false
    {
      // acc := DebugAccumulator.EmptyAccumulator();
      // //var r := new DebugAccumulator.AccRec(syncReqs.Count, "SyncReqStatus");
      // //acc := DebugAccumulator.AccPut(acc, "syncReqs", r);
      // var i := DebugAccumulator.EmptyAccumulator();
      // if persistentIndirectionTable != null {
      //   i := persistentIndirectionTable.DebugAccumulate();
      // }
      // var a := new DebugAccumulator.AccRec.Index(i);
      // acc := DebugAccumulator.AccPut(acc, "persistentIndirectionTable", a);
      // i := DebugAccumulator.EmptyAccumulator();
      // if frozenIndirectionTable != null {
      //   i := frozenIndirectionTable.DebugAccumulate();
      // }
      // a := new DebugAccumulator.AccRec.Index(i);
      // acc := DebugAccumulator.AccPut(acc, "frozenIndirectionTable", a);
      // i := DebugAccumulator.EmptyAccumulator();
      // if ephemeralIndirectionTable != null {
      //   i := ephemeralIndirectionTable.DebugAccumulate();
      // }
      // a := new DebugAccumulator.AccRec.Index(i);
      // acc := DebugAccumulator.AccPut(acc, "ephemeralIndirectionTable", a);
      // //r := new DebugAccumulator.AccRec(if outstandingIndirectionTableWrite.Some? then 1 else 0, "ReqId");
      // //acc := DebugAccumulator.AccPut(acc, "outstandingIndirectionTableWrite", r);
      // //r := new DebugAccumulator.AccRec(|outstandingBlockWrites| as uint64, "OutstandingWrites");
      // //acc := DebugAccumulator.AccPut(acc, "outstandingBlockWrites", r);
      // //r := new DebugAccumulator.AccRec(|outstandingBlockReads| as uint64, "OutstandingReads");
      // //acc := DebugAccumulator.AccPut(acc, "outstandingBlockReads", r);
      // i := cache.DebugAccumulate();
      // a := new DebugAccumulator.AccRec.Index(i);
      // acc := DebugAccumulator.AccPut(acc, "cache", a);
      // i := lru.DebugAccumulate();
      // a := new DebugAccumulator.AccRec.Index(i);
      // acc := DebugAccumulator.AccPut(acc, "lru", a);
      // i := blockAllocator.DebugAccumulate();
      // a := new DebugAccumulator.AccRec.Index(i);
      // acc := DebugAccumulator.AccPut(acc, "blockAllocator", a);
    }

    predicate ConsistentBitmap()
      requires Ready? && blockAllocator.Inv()
    {
      ConsistentBitmapInteral(ephemeralIndirectionTable.I(), if frozenIndirectionTable.lSome? then lSome(frozenIndirectionTable.value.I()) else lNone,
          persistentIndirectionTable.I(), outstandingBlockWrites, blockAllocator.I())
    }

    shared function method TotalCacheSize() : (res : uint64)
    requires Ready?
    requires cache.Inv()
    requires |cache.I()| + |outstandingBlockReads| < 0x1_0000_0000_0000_0000
    ensures res as int == totalCacheSize()
    {
      CacheImpl.CacheCount(cache) + (|outstandingBlockReads| as uint64)
    }

    // TODO reuse the definition in BlockCache?
    function totalCacheSize() : int
    requires Ready?
    requires cache.Inv()
    {
      |cache.I()| + |outstandingBlockReads|
    }

    predicate W()
    {
      Ready? ==> (
        && persistentIndirectionTable.Inv()
        && (frozenIndirectionTable.lSome? ==> frozenIndirectionTable.value.Inv())
        && ephemeralIndirectionTable.Inv()
        && lru.Inv()
        && cache.Inv()
        && blockAllocator.Inv()
      )
    }

    predicate WFBCVars()
    {
      && W()
      && (Ready? ==> 
        (
          && LruModel.WF(lru.Queue())
          && LruModel.I(lru.Queue()) == cache.I().Keys
          && totalCacheSize() <= MaxCacheSize()
          && ephemeralIndirectionTable.TrackingGarbage()
          && BlockAllocatorModel.Inv(blockAllocator.I())
          && ConsistentBitmap()
          && WFCache(cache.I())
        )
      )
    }

    predicate WriteAllocConditions()
    {
      && Ready?
      && ephemeralIndirectionTable.Inv()
      && ephemeralIndirectionTable.TrackingGarbage()
      && blockAllocator.Inv()
      && (forall loc | loc in ephemeralIndirectionTable.I().locs.Values :: DiskLayout.ValidNodeLocation(loc))
      // && (forall r | r in ephemeralIndirectionTable.graph :: r <= ephemeralIndirectionTable.refUpperBound)
      && ConsistentBitmap()
      && BlockAllocatorModel.Inv(blockAllocator.I())
      && BC.AllLocationsForDifferentRefsDontOverlap(ephemeralIndirectionTable.I())
    }

    function I() : BBC.Variables
    requires W()
    {
      if Ready? then (
        BC.Ready(persistentIndirectionTable.I(), 
          if frozenIndirectionTable.lSome? then Some(frozenIndirectionTable.value.I()) else None,
          ephemeralIndirectionTable.I(),
          persistentIndirectionTableLoc,
          frozenIndirectionTableLoc,
          outstandingIndirectionTableWrite,
          outstandingBlockWrites,
          outstandingBlockReads,
          cache.I())
      ) else if Loading? then (
        BC.LoadingIndirectionTable(indirectionTableLoc, indirectionTableRead)
      ) else (
        BC.Unready
      )
    }

    predicate Inv()
    {
      && WFBCVars()
      && BBC.Inv(I())
    }

    predicate ChildrenConditions(succs: Option<seq<BT.G.Reference>>)
    requires Ready?
    {
      succs.Some? ==> (
        && |succs.value| <= MaxNumChildren()
        && IT.IndirectionTable.SuccsValid(succs.value, ephemeralIndirectionTable.graph)
      )
    }

    static method Constructor() returns (linear v: Variables)
    ensures v.Unready?
    ensures v.WFBCVars()
    {
      v := Unready;
    }
  }
}
