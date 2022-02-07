Supplemental Material for "Linear Types for Large-Scale Systems Verification"
-----------------------------------------------------------------------------

The following files contain the formal language definition and proofs:

  * defs.txt -- definitions of syntax, typing rules, and semantics
  * proofs.txt -- proofs of soundness (type preservation, wp-preservation, progress, region agreement preservation)
  * algorithm.txt -- definitions and proofs for type inference algorithm (type inference soundness, type inference completeness)

The following linked files contain the region library and doubly linked list module:
  * [LinearRegionDLinkList.dfy](https://github.com/jialin-li/linear-veribetrkv-artifact/blob/master/veribetrkv-linear/lib/Lang/LinearRegionDLinkList.dfy) -- declaration of region library and implementation of doubly linked list
  * [LinearRegion_s.h](https://github.com/jialin-li/linear-veribetrkv-artifact/blob/master/veribetrkv-linear/lib/Lang/LinearRegion_s.h) -- trusted implementation of region library in C++