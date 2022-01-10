# match linearized methods back to dynamic frame ones
# 1st level key is indexed by linear file name
# the value contains corresponding name in DF version and methods mapping

EQUIV_MAP = {
  "CacheImpl/LMutCache" : {
    "dname": ["CacheImpl/MutCache"],
    "methods" : {
        "NewCache" : "constructor",
        "Get" : "GetOpt",
        "RemoveAndGet" : "Remove",      
    }
  },
  "MarshallingImpl" : {
    "dname" : ["MarshallingImpl"],
    "methods" : {
      "IsStrictlySortedPivots" : "IsStrictlySortedKeySeq",
      "KeyValSeqToPivots" : "KeyValSeqToKeySeq",
      "valToStrictlySortedPivots" : "ValToStrictlySortedKeySeq",
      "strictlySortedPivotsToVal": "strictlySortedKeySeqToVal"
    } 
  },
  "JournalistImpl/Journalist" : {
      "dname": ["JournalistImpl/Journalist"],
      "splits" : {
          "append" : "reallocJournalEntries"
      },  # represent linear method that needs to be combined to be comparable to dyanmic frame methods
      "methods" : {
          "Constructor" : "constructor",
      }
  },
  "BucketImpl/MutBucket" : {
      "dname" : ["BucketImpl/MutBucket"],
      "methods" : {
          "Alloc" : "constructor",
          "AllocPkv" : "InitFromPkv",
          "Constructor" : "constructor",
      }
  },
  "FlushImpl" : {
      "dname" : ["FlushImpl"],
      "splits" : {
          "flush" : "doFlush"
      },
      "methods" : {}
  },
  "InsertImpl" : {
      "dname" : ["InsertImpl"],
      "methods" : {
          "insertKeyValue" : "InsertKeyValue"
      }
  },
  "SuccImpl": {
      "dname" : ["BucketGeneratorImpl/Generator"],
      "methods" : {
          "composeGenerator" : "GenFromBucketStackWithLowerBound"
      }
  },
  "IndirectionTable/IndirectionTable": {
      "dname" : ["IndirectionTableImpl/IndirectionTable"],
      "methods" : {
          "Alloc" : "RootOnly",
          "AllocEmpty" : "Empty",
          "IndirectionTableToVal" : "indirectionTableToVal"
      }
  },
  "IndirectionTable": {
      "dname" : ["IndirectionTableModel"],
      "methods" : {}
  },
  "BlockAllocatorImpl/BlockAllocator" : {
      "dname" : ["BlockAllocatorImpl/BlockAllocator"],
      "methods": {
          "Constructor" : "constructor"
      }
  },
  "GrowImpl" : {
      "dname" : ["GrowImpl"],
      "splits" : {
          "grow" : "doGrow"
      },
      "methods" : {}
  },
  "BitmapImpl/Bitmap" : {
      "dname": ["BitmapImpl/Bitmap"],
      "methods" : {
          "Constructor": "constructor",
          "UnionConstructor": "Union",
          "CloneConstructor": "Clone"
      }
  },
  "LKMBPKVOps": {
      "dname" : ["KMBPKVOps"],
      "methods" : {}
  },
  "StateBCImpl/Variables": {
      "dname" : ["StateImpl/Variables"],
      "methods" : {
          "Constructor" : "constructor"
      }
  },
  "LeafImpl": {
      "dname" : ["LeafImpl"],
      "methods" : {},
      "splits" : {
          "repivotLeaf" : "repivotLeafInternal"
      }
  },
  "CoordinationImpl" : {
      "dname" : ["CoordinationImpl"],
      "methods" : {},
      "splits" : {
          "popSync" : "getCommitterSyncState",
          "isInitialized" : "isCommitterStatusReady",
          "insert" : "canJournalistAppend"
      }
  },
  "SplitImpl" : {
      "dname" : ["SplitImpl"],
      "methods" : {},
      "splits" : {
          "doSplit" : "split"
      }
  },
  "NodeImpl/Node" : {
      "dname" : ["NodeImpl/Node"],
      "methods" : {
          "Alloc" : "constructor"
      },
  },
  "CommitterImpl/Committer" : {
      "dname" : ["CommitterAppendImpl", "CommitterCommitModel", "CommitterCommitImpl", "CommitterImpl/Committer", "CommitterInitImpl", "CommitterReplayImpl", "HandleWriteResponseImpl", "HandleReadResponseImpl"],
      "methods" : {
          "Constructor" : "constructor",
          "journalAppend" : "JournalAppend",
          "journalReplayOne" : "JournalReplayOne",
          "pageInSuperblockReq" : "PageInSuperblockReq",
          "finishLoadingSuperblockPhase" : "FinishLoadingSuperblockPhase",
          "pageInJournalResp" : "PageInJournalResp"
      }
  },
  "CommitterImpl" : {
      "dname" : ["CommitterCommitImpl"],
      "methods" : {
        #   "Constructor" : "constructor",
        #   "journalAppend" : "JournalAppend",
        #   "journalReplayOne" : "JournalReplayOne",
        #   "pageInSuperblockReq" : "PageInSuperblockReq",
        #   "finishLoadingSuperblockPhase" : "FinishLoadingSuperblockPhase",
        #   "pageInJournalResp" : "PageInJournalResp"
      }
  }
}
