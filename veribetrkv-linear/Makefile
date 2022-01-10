# Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
# SPDX-License-Identifier: BSD-2-Clause

##############################################################################
# System configuration

# You can build anything reachable from these root files.
DAFNY_ROOTS=Impl/Bundle.i.dfy build-tests/test-suite.i.dfy Splinter/RefinementProof.i.dfy

DAFNY_ROOT?=.dafny/dafny/
DAFNY_CMD=$(DAFNY_ROOT)/Scripts/dafny
DAFNY_BINS=$(wildcard $(DAFNY_ROOT)/Binaries/*)
DAFNY_FLAGS=
# Approximation based on (somewhat dated) F* measurements
RLIMIT_PER_SECOND=545
DEFAULT_RLIMIT=$$(( 30 * $(RLIMIT_PER_SECOND) ))
DAFNY_RLIMIT_FLAG=/rlimit:$(DEFAULT_RLIMIT)

# This is mainly for CI use
DAFNY_GLOBAL_FLAGS=

POUND_DEFINES=
ifdef LOG_QUERY_STATS
	POUND_DEFINES += -DLOG_QUERY_STATS
endif

CC=clang++
STDLIB?=-stdlib=libc++

# Uncomment to enable gprof
#GPROF_FLAGS=-pg

WANT_UNVERIFIED_ROW_CACHE=false
ifeq "$(WANT_UNVERIFIED_ROW_CACHE)" "true"
	UNVERIFIED_ROW_CACHE_DEFINE=-DUSE_UNVERIFIED_ROW_CACHE
else
	UNVERIFIED_ROW_CACHE_DEFINE=
endif

WANT_MALLOC_ACCOUNTING=false
ifeq "$(WANT_MALLOC_ACCOUNTING)" "true"
	MALLOC_ACCOUNTING_DEFINE=-DMALLOC_ACCOUNTING=1
else
	MALLOC_ACCOUNTING_DEFINE=
endif

WANT_DEBUG=false
ifeq "$(WANT_DEBUG)" "true"
	DBG_SYMBOLS_FLAG=-g
	OPT_FLAG=-O0
else
	DBG_SYMBOLS_FLAG=
	OPT_FLAG=-O3
endif

# _LIBCPP_HAS_NO_THREADS makes shared_ptr faster
# (but also makes stuff not thread-safe)
# Note: this optimization only works with stdlib=libc++
OPT_FLAGS=$(MALLOC_ACCOUNTING_DEFINE) \
          $(UNVERIFIED_ROW_CACHE_DEFINE) \
          $(DBG_SYMBOLS_FLAG) \
          $(OPT_FLAG) \
          -D_LIBCPP_HAS_NO_THREADS \
          $(GPROF_FLAGS)

##############################################################################
# Automatic targets

all: status elf

clean:
	rm -rf build
	@$(MAKE) -C ycsb clean

##############################################################################
# Build dir and dependency setup

.PRECIOUS: build/. build%/.
# .SECONDEXPANSION Needed to make $$(@D) trick work.
# http://ismail.badawi.io/blog/2017/03/28/automatic-directory-creation-in-make/
.SECONDEXPANSION:

# Make build/ directory
build/.:
	mkdir -p $@

# Ensure deps gets rebuilt if someone changes DAFNY_ROOTS
build/roots: | $$(@D)/.
	echo $(DAFNY_ROOTS) > $@

# Make generated build/deps file.
build/deps: tools/veridepend.py tools/lib_deps.py build/roots | build/.
	tools/veridepend.py $(DAFNY_ROOTS)

include build/deps

# Make build/ subdirectories, as demanded by rules in generated build/deps file.
build%/.:
	mkdir -p $@

##############################################################################
# Helpers for rules.

# tee_capture lets us see the output of commands during the make, but also
# capture it in the build/ result file. It's trickier than you'd think,
# because we need to:
# (a) cause the rule to fail if the command fails. By default, the shell
# reports whether 'tee' failed.
# (b) not create the output file if the command fails, hence the TMPNAME.
# Use bash so PIPESTATUS works
SHELL=/bin/bash
define tee_capture
	$(eval TMPNAME=$(patsubst %,%-tmp,$1))
	$(2) 2>&1 | tee $(TMPNAME); test $${PIPESTATUS[0]} -eq 0
	mv $(TMPNAME) $1
endef

##############################################################################
##############################################################################
# Special top-level targets

##############################################################################
# Verification status page

.PHONY: status
status: build/deps build/Impl/Bundle.i.status.pdf build/Impl/Bundle.i.status.svg build/Impl/Bundle.i.status.txt

# Longer time-limit for CI
.PHONY: verichecks-status

verichecks-status: DAFNY_GLOBAL_FLAGS=/vcsCores:4
verichecks-status: DEFAULT_RLIMIT=$$(( 30 * $(RLIMIT_PER_SECOND) ))
verichecks-status: status

.PHONY: syntax-status
syntax-status: build/deps build/Impl/Bundle.i.syntax-status.pdf build/Impl/Bundle.i.syntax-status.svg build/Impl/Bundle.i.syntax-status.txt

.PHONY: verify-ordered
verify-ordered: build/deps build/Impl/Bundle.i.okay

##############################################################################
# C++ executables

.PHONY: allcpp
allcpp: build/Impl/Bundle.i.cpp

.PHONY: allo
allo: build/Impl/Bundle.i.o

.PHONY: elf
elf: build/Veribetrfs

##############################################################################
##############################################################################
# Pattern rules

# This was cool until someone tried to run it on MacOS.
#TIME=time -f "real %es cpu %Us"
#TIME=/usr/bin/time --format '%Uuser'
TIME=/usr/bin/time

##############################################################################
# Dummy dependency chains, so that a rule that depends on a top-level .dfy
# file can be made to depend on all of the included dfys reachable from there.
build/%.dummydep: %.dfy | $$(@D)/.
	touch $@

##############################################################################
# .synchk: Dafny syntax check
build/%.synchk: %.dfy $(DAFNY_BINS) | $$(@D)/.
	$(eval TMPNAME=$(patsubst %.synchk,%.synchk-tmp,$@))
	( $(TIME) $(DAFNY_CMD) /compile:0 /dafnyVerify:0 $< ) 2>&1 | tee $(TMPNAME)
	mv $(TMPNAME) $@

##############################################################################
# .verchk: Dafny file-local verification
build/%.verchk: %.dfy $(DAFNY_BINS) | $$(@D)/.
	$(eval TMPNAME=$(patsubst %.verchk,%.verchk-tmp,$@))
	( $(TIME) $(DAFNY_CMD) $(DAFNY_GLOBAL_FLAGS) $(DAFNY_RLIMIT_FLAG) $(DAFNY_FLAGS) /compile:0 $< ) 2>&1 | tee $(TMPNAME)
	mv $(TMPNAME) $@

### Establish Dafny flag defaults

# this flag means _NO_ non-linear arithmetic
# unfortunately it can only be set on a per-file basis?

NONLINEAR_FLAGS = /noNLarith

# Only use auto-induction when specified, across all files.
# To enable auto-induction, add {:induction true} to your source file.

INDUCTION_FLAGS = /induction:1

OTHER_PROVER_FLAGS =

### Adjust defaults for a couple of files
# (It would be nice if we could do this in the source instead.)

# enable nonlinear arithmetic for some files
# Note: Nonlinear.i.dfy and Math.i.dfy are designed to use nonlinear arith.
# The other files are legacy'ed in, but it's no big deal as long
# as they verify.
build/lib/Math/Nonlinear.i.verchk: NONLINEAR_FLAGS=
build/lib/Base/mathematics.i.verchk: NONLINEAR_FLAGS=
build/Impl/BookkeepingModel.i.verchk: NONLINEAR_FLAGS=
build/Impl/IOImpl.i.verchk: NONLINEAR_FLAGS=
build/Impl/IOModel.i.verchk: NONLINEAR_FLAGS=
build/Impl/SyncImpl.i.verchk: NONLINEAR_FLAGS=
build/Impl/BookkeepingImpl.i.verchk: NONLINEAR_FLAGS=
build/lib/Base/SetBijectivity.i.verchk: NONLINEAR_FLAGS=
build/lib/Marshalling/GenericMarshalling.i.verchk: NONLINEAR_FLAGS=
build/lib/Buckets/BucketFlushModel.i.verchk: NONLINEAR_FLAGS=
build/lib/Buckets/PackedStringArray.i.verchk: NONLINEAR_FLAGS=
build/lib/Base/Sequences.i.verchk: NONLINEAR_FLAGS=
build/BlockCacheSystem/DiskLayout.i.verchk: NONLINEAR_FLAGS=
build/ByteBlockCacheSystem/Marshalling.i.verchk: NONLINEAR_FLAGS=
build/ByteBlockCacheSystem/JournalBytes.i.verchk: NONLINEAR_FLAGS=
build/PivotBetree/Bounds.i.verchk: NONLINEAR_FLAGS=
build/Impl/Mkfs.i.verchk: NONLINEAR_FLAGS=
build/Impl/MkfsModel.i.verchk: NONLINEAR_FLAGS=
build/Impl/MarshallingImpl.i.verchk: NONLINEAR_FLAGS=


### Put all the flags together

DAFNY_FLAGS = $(NONLINEAR_FLAGS) $(INDUCTION_FLAGS) $(OTHER_PROVER_FLAGS)

##############################################################################
# .okay: Dafny file-level verification, no time limit,
# verifies in dependency order.
# This is currently Travis's favorite build rule.

build/%.okay: %.dfy | $$(@D)/.
	$(TIME) $(DAFNY_CMD) /compile:0 $<
	touch $@

##############################################################################
# .verified: Aggregate result of verification for this file and
# its dependencies.
.PRECIOUS: build/%.verchk
AGGREGATE_TOOL=tools/aggregate-verchk.py
build/%.verified: build/%.verchk $(AGGREGATE_TOOL) | $$(@D)/.
	$(AGGREGATE_TOOL) --verchk --root $< --summary $@ --error $@.err

# Syntax is trivial from synchk file, just a marker.
# (We need the .syntax target to get a recursive dependency computation.)
build/%.syntax: build/%.synchk $(AGGREGATE_TOOL) | $$(@D)/.
	$(AGGREGATE_TOOL) --synchk --root $< --summary $@ --error $@.err

##############################################################################
# .status.pdf and .status.svg: a dependency graph of .dfy files labeled with verification result status.
#
STATUS_TOOL=tools/dep-graph.py
STATUS_DEPS=tools/lib_aggregate.py
build/%.status.pdf: %.dfy build/%.verified $(STATUS_TOOL) $(STATUS_DEPS) build/deps | $$(@D)/.
	@$(eval DOTNAME=$(patsubst %.pdf,%.dot,$@))	 #eval trick to assign make var inside rule
	$(STATUS_TOOL) verchk $< $(DOTNAME)
	@tred < $(DOTNAME) | dot -Tpdf -o$@

build/%.status.svg: %.dfy build/%.verified $(STATUS_TOOL) $(STATUS_DEPS) build/deps | $$(@D)/.
	@$(eval DOTNAME=$(patsubst %.svg,%.dot,$@))	 #eval trick to assign make var inside rule
	$(STATUS_TOOL) verchk $< $(DOTNAME)
	@tred < $(DOTNAME) | dot -Tsvg -o$@

# A syntax-only version of the tree so I can play around without waiting for
# a complete verification.
build/%.syntax-status.pdf: %.dfy build/%.syntax $(STATUS_TOOL) $(STATUS_DEPS) build/deps | $$(@D)/.
	$(eval DOTNAME=$(patsubst %.pdf,%.dot,$@))	 #eval trick to assign make var inside rule
	$(STATUS_TOOL) synchk $< $(DOTNAME)
	@tred < $(DOTNAME) | dot -Tpdf -o$@

build/%.syntax-status.svg: %.dfy build/%.syntax $(STATUS_TOOL) $(STATUS_DEPS) build/deps | $$(@D)/.
	$(eval DOTNAME=$(patsubst %.svg,%.dot,$@))	 #eval trick to assign make var inside rule
	$(STATUS_TOOL) synchk $< $(DOTNAME)
	@tred < $(DOTNAME) | dot -Tsvg -o$@

##############################################################################
# .status.txt: a simple text file listing all source files with errors
#
REPORT_TOOL=tools/gen-build-report.py
REPORT_DEPS=tools/lib_deps.py tools/lib_aggregate.py
build/%.status.txt: %.dfy build/%.verified $(REPORT_TOOL) $(REPORT_DEPS) build/deps | $$(@D)/.
	$(REPORT_TOOL) verchk $< $@

build/%.syntax-status.txt: %.dfy build/%.syntax $(REPORT_TOOL) $(REPORT_DEPS) build/deps | $$(@D)/.
	$(REPORT_TOOL) synchk $< $@

##############################################################################
# .lcreport: Tabular data on line counts of {spec, impl, proof}
#.PRECIOUS: build/%.lc --Why isn't this necessary?
LC_TOOL=tools/line_counter.py
LC_DEPS=tools/line_count_lib.py tools/lib_aggregate.py tools/lib_deps.py
build/%.lc: %.dfy build/%.syntax $(LC_TOOL) $(LC_DEPS)
		$(LC_TOOL) --mode count --input $< --output $@

LC_REPORT_DEPS=tools/line_counter_report_lib.py
build/%.lcreport: %.dfy build/%.lc $(LC_TOOL) $(LC_DEPS) $(LC_REPORT_DEPS)
		$(LC_TOOL) --mode report --input $< --output $@

##############################################################################
# .cs: C-Sharp output from compiling a Dafny file (which includes all deps)
# In principle, building code should depend on .verified! But we want
# to play with perf with not-entirely-verifying trees.
build/%.cs: %.dfy $(DAFNY_BINS) | $$(@D)/.
#eval trick to assign make var inside rule
# Dafny irritatingly removes the '.i' presuffix, and has a weird behavior where it duplicates prefixes of relative paths. Bizarre.
	$(eval TMPNAME=$(abspath $(patsubst %.s.cs,%-s.cs,$(patsubst %.i.cs,%-i.cs,$@))))
	pwd
	$(TIME) $(DAFNY_CMD) /compile:0 /noVerify /spillTargetCode:3 /countVerificationErrors:0 /out:$(TMPNAME) $<
	mv $(TMPNAME) $@

##############################################################################
# .cpp: C++ output from compiling a Dafny file (which includes all deps)
# Slow, but useful for iterating when working on the cpp compiler.
build/%.cpp: %.dfy $(DAFNY_BINS) | $$(@D)/.
#eval trick to assign make var inside rule
	$(eval TMPNAME=$(abspath $(patsubst %.cpp,%-i.cpp,$@)))
# Dafny irritatingly removes the '.i' presuffix.
	$(TIME) $(DAFNY_CMD) /compile:0 /noVerify /spillTargetCode:3 /countVerificationErrors:0 /out:$(TMPNAME) /compileTarget:cpp $< Framework.h
	mv $(TMPNAME) $@

# Build the main cpp file without building all the partial cpp files.
build/Bundle.cpp: Impl/Bundle.i.dfy build/Impl/Bundle.i.dummydep $(DAFNY_BINS) | $$(@D)/.
#eval trick to assign make var inside rule
	$(eval TMPNAME=$(abspath $(patsubst %.cpp,%-i.cpp,$@)))
	$(TIME) $(DAFNY_CMD) /compile:0 /noVerify /spillTargetCode:3 /countVerificationErrors:0 /out:$(TMPNAME) /compileTarget:cpp $< Framework.h
	mv $(TMPNAME) $@

build/Bundle.i.h: build/Bundle.cpp
# this is build automatically when we build Bundle.cpp
	touch build/Bundle.i.h

##############################################################################
# C++ object files

CPP_DEP_DIR=build/cppdeps
GEN_H_FILES=build/Bundle.i.h

WARNINGS=-Wall -Wsign-compare

build/%.o: build/%.cpp $(GEN_H_FILES) | $$(@D)/.
	@mkdir -p $(CPP_DEP_DIR)/$(basename $<)
	$(CC) $(STDLIB) -c $< -o $@ -I$(DAFNY_ROOT)/Binaries/ -I framework/ -std=c++17 -msse4.2 $(POUND_DEFINES) -MMD -MP -MF "$(CPP_DEP_DIR)/$(<:.cpp=.d)" $(CCFLAGS) $(OPT_FLAGS) $(WARNINGS)

build/framework/%.o: framework/%.cpp $(GEN_H_FILES) | $$(@D)/.
	@mkdir -p $(CPP_DEP_DIR)/$(basename $<)
	$(CC) $(STDLIB) -c $< -o $@ -I$(DAFNY_ROOT)/Binaries/ -I framework/ -I build/ -std=c++17 -march=native -msse4.2 $(POUND_DEFINES) -MMD -MP -MF "$(CPP_DEP_DIR)/$(<:.cpp=.d)" $(CCFLAGS) $(OPT_FLAGS) $(WARNINGS) -Werror

# the BundleWrapper.cpp file includes the auto-generated Bundle.cpp
build/framework/BundleWrapper.o: framework/BundleWrapper.cpp build/Bundle.cpp $(GEN_H_FILES) | $$(@D)/.
	@mkdir -p $(CPP_DEP_DIR)/$(basename $<)
# No -Werror
	$(CC) $(STDLIB) -c $< -o $@ -I$(DAFNY_ROOT)/Binaries/ -I framework/ -I build/ -std=c++17 -march=native -msse4.2 -MMD -MP -MF "$(CPP_DEP_DIR)/$(<:.cpp=.d)" $(CCFLAGS) $(OPT_FLAGS) $(WARNINGS)

# Include the .h depencies for all previously-built .o targets. If one of the .h files
# changes, we'll rebuild the .o
rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))
-include $(call rwildcard,$(CPP_DEP_DIR)/,*.d)

VERIBETRFS_AUX_FILES=\
	build/framework/Benchmarks.o \
	build/framework/BundleWrapper.o \
	build/framework/UnverifiedRowCache.o \
	build/framework/Framework.o \
	build/framework/MallocAccounting.o \

VERIBETRFS_O_FILES=\
	$(VERIBETRFS_AUX_FILES)\
	build/framework/Main.o \

LDFLAGS=-msse4.2

# On linux we need the -lrt (for aio functions),
# but on mac it doesn't exist.
UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
else
LDFLAGS += -lrt
endif

build/Veribetrfs: $(VERIBETRFS_O_FILES)
	$(CC) $(STDLIB) -o $@ $(VERIBETRFS_O_FILES) $(CCFLAGS) $(LDFLAGS) $(GPROF_FLAGS)

##############################################################################
# YCSB

VERIBETRFS_YCSB_O_FILES=\
	$(VERIBETRFS_AUX_FILES)\
	build/framework/leakfinder.o \

libycsbc: build/libycsbc-libcpp.a \
				  build/libycsbc-default.a

build/libycsbc-libcpp.a:
	STDLIB=libcpp $(MAKE) -C ycsb build/libycsbc-libcpp.a

build/libycsbc-default.a:
	STDLIB=default $(MAKE) -C ycsb build/libycsbc-default.a

librocksdb:
	@env \
		ROCKSDB_DISABLE_BZIP=1 \
		ROCKSDB_DISABLE_ZLIB=1 \
		ROCKSDB_DISABLE_LZ4=1 \
		ROCKSDB_DISABLE_ZSTD=1 \
		ROCKSDB_DISABLE_JEMALLOC=1 \
		ROCKSDB_DISABLE_SNAPPY=1 \
		$(MAKE) -C vendor/rocksdb static_lib

.PHONY: libycsbc

build/YcsbMain.o: ycsb/YcsbMain.cpp
	$(CC) $(STDLIB) -c -o $@ \
			-I ycsb/build/include \
			-I $(DAFNY_ROOT)/Binaries/ \
			-I framework/ \
			-I build/ \
			-I vendor/hdrhist/ \
			-I vendor/rocksdb/include/ \
			-Winline -std=c++17 $(O3FLAG) \
			-D_YCSB_VERIBETRFS \
			$(POUND_DEFINES) \
			$(MALLOC_ACCOUNTING_DEFINE) \
			$(DBG_SYMBOLS_FLAG) \
			$(GPROF_FLAGS) \
			$^

build/VeribetrfsYcsb: $(VERIBETRFS_YCSB_O_FILES) build/libycsbc-libcpp.a build/YcsbMain.o
	# NOTE: this uses c++17, which is required by hdrhist
	$(CC) $(STDLIB) -o $@ \
			-Winline -std=c++17 $(O3FLAG) \
			-L ycsb/build \
			-L vendor/rocksdb \
			$(DBG_SYMBOLS_FLAG) \
			$(VERIBETRFS_YCSB_O_FILES) \
			build/YcsbMain.o \
			-lycsbc-libcpp -lpthread -ldl $(LDFLAGS)

build/RocksYcsb: build/libycsbc-default.a librocksdb ycsb/YcsbMain.cpp
	# NOTE: this uses c++17, which is required by hdrhist
	$(CC) -o $@ \
			-L ycsb/build \
			-L vendor/rocksdb \
			-I ycsb/build/include \
			-I $(DAFNY_ROOT)/Binaries/ \
			-I framework/ \
			-I build/ \
			-I vendor/hdrhist/ \
			-I vendor/rocksdb/include/ \
			-Winline -std=c++17 $(O3FLAG) \
			-D_YCSB_ROCKS \
			$(POUND_DEFINES) \
			ycsb/YcsbMain.cpp \
			-lycsbc-default -lrocksdb -lpthread -ldl $(LDFLAGS) \

vendor/kyoto/kyotocabinet/libkyotocabinet.a:
	(cd vendor/kyoto/kyotocabinet; CXX=clang++ CXXFLAGS=$(STDLIB) ./configure; make)

build/KyotoYcsb: ycsb/YcsbMain.cpp build/libycsbc-libcpp.a vendor/kyoto/kyotocabinet/libkyotocabinet.a
	# NOTE: this uses c++17, which is required by hdrhist
	$(CC) \
      $(STDLIB) \
      -o $@ \
			-Winline -std=c++17 $(O3FLAG) \
			-L ycsb/build \
			-I ycsb/build/include \
			-I $(DAFNY_ROOT)/Binaries/ \
			-I framework/ \
			-I build/ \
			-I vendor/hdrhist/ \
			-I vendor/kyoto/kyotocabinet \
			-L vendor/kyoto/kyotocabinet \
			$(DBG_SYMBOLS_FLAG) \
			-D_YCSB_KYOTO \
			ycsb/YcsbMain.cpp \
			vendor/kyoto/kyotocabinet/libkyotocabinet.a \
			-lycsbc-libcpp -lpthread -ldl -lz $(LDFLAGS)

# Requires libdb-stl-dev to be installed (on debian, libdbb5.3-stl-dev)
build/BerkeleyYcsb: ycsb/YcsbMain.cpp build/libycsbc-libcpp.a
	# NOTE: this uses c++17, which is required by hdrhist
	$(CC) \
      $(STDLIB) \
      -o $@ \
			-Winline -std=c++17 $(O3FLAG) \
			-L ycsb/build \
			-I ycsb/build/include \
			-I $(DAFNY_ROOT)/Binaries/ \
			-I framework/ \
			-I build/ \
			-I vendor/hdrhist/ \
			$(DBG_SYMBOLS_FLAG) \
			-D_YCSB_BERKELEYDB \
			ycsb/YcsbMain.cpp \
			-lycsbc-libcpp -lpthread -ldl -lz -ldb_stl $(LDFLAGS)


ycsb: build/VeribetrfsYcsb build/RocksYcsb build/KyotoYcsb build/BerkeleyYcsb
