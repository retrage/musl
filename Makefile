#
# Makefile for musl (requires GNU make)
#
# This is how simple every makefile should be...
# No, I take that back - actually most should be less than half this size.
#
# Use config.mak to override any of the following variables.
# Do not make changes here.
#

srcdir = .
exec_prefix = /usr/local
bindir = $(exec_prefix)/bin

prefix = /usr/local/musl
includedir = $(prefix)/include
libdir = $(prefix)/lib
syslibdir = /lib

BASE_SRCS = $(sort $(wildcard $(srcdir)/src/*/*.c))
BASE_OBJS = $(patsubst $(srcdir)/%,%.o,$(basename $(BASE_SRCS)))
ARCH_SRCS = $(wildcard $(srcdir)/src/*/$(ARCH)/*.[csS])
ARCH_OBJS = $(patsubst $(srcdir)/%,%.o,$(basename $(ARCH_SRCS)))
REPLACED_OBJS = $(sort $(subst /$(ARCH)/,/,$(ARCH_OBJS)))
LDSO_SRCS = $(sort $(wildcard $(srcdir)/ldso/*.c))
LDSO_OBJS = $(patsubst $(srcdir)/%,obj/%.lo,$(basename $(LDSO_SRCS)))
OBJS = $(addprefix obj/, $(filter-out $(REPLACED_OBJS), $(sort $(BASE_OBJS) $(ARCH_OBJS))))
AOBJS = $(OBJS)
LOBJS = $(OBJS:.o=.lo)
GENH = obj/include/bits/alltypes.h obj/include/bits/stat.h
GENH_INT = obj/src/internal/version.h
IMPH = $(addprefix $(srcdir)/, src/internal/stdio_impl.h src/internal/pthread_impl.h src/internal/libc.h)

LDFLAGS =
LDFLAGS_AUTO =
LIBCC = -lgcc
CPPFLAGS =
CFLAGS =
CFLAGS_AUTO = -Os -pipe
CFLAGS_C99FSE = -std=c99 -ffreestanding -nostdinc 

CFLAGS_ALL = $(CFLAGS_C99FSE) $(CFLAGS_LKL0)
CFLAGS_ALL += -D_XOPEN_SOURCE=700 -I$(srcdir)/arch/$(ARCH) -I$(srcdir)/arch/generic -Iobj/src/internal -I$(srcdir)/src/internal -Iobj/include -I$(srcdir)/include
CFLAGS_ALL += $(CPPFLAGS) $(CFLAGS_AUTO) $(CFLAGS) $(CFLAGS_LKL1)

LDFLAGS_ALL = $(LDFLAGS_AUTO) $(LDFLAGS)

AR      = $(CROSS_COMPILE)ar
RANLIB  = $(CROSS_COMPILE)ranlib
INSTALL = $(srcdir)/tools/install.sh

ARCH_INCLUDES = $(wildcard $(srcdir)/arch/$(ARCH)/bits/*.h)
GENERIC_INCLUDES = $(wildcard $(srcdir)/arch/generic/bits/*.h)
INCLUDES = $(wildcard $(srcdir)/include/*.h $(srcdir)/include/*/*.h)
ALL_INCLUDES = $(sort $(INCLUDES:$(srcdir)/%=%) $(GENH:obj/%=%) $(ARCH_INCLUDES:$(srcdir)/arch/$(ARCH)/%=include/%) $(GENERIC_INCLUDES:$(srcdir)/arch/generic/%=include/%))

EMPTY_LIB_NAMES = m rt pthread crypt util xnet resolv dl
EMPTY_LIBS = $(EMPTY_LIB_NAMES:%=lib/lib%.a)
CRT_LIBS = lib/crt1.o lib/Scrt1.o lib/rcrt1.o lib/crti.o lib/crtn.o
STATIC_LIBS = lib/libc.a
SHARED_LIBS = lib/libc.so
TOOL_LIBS = lib/musl-gcc.specs
ALL_LIBS = $(CRT_LIBS) $(STATIC_LIBS) $(SHARED_LIBS) $(EMPTY_LIBS) $(TOOL_LIBS)
ALL_TOOLS = obj/musl-gcc

WRAPCC_GCC = gcc
WRAPCC_CLANG = clang

LDSO_PATHNAME = $(syslibdir)/ld-musl-$(ARCH)$(SUBARCH).so.1

-include config.mak

ifeq ($(ARCH),)
$(error Please set ARCH in config.mak before running make.)
endif

# exclude some files for frankenlibc
BASE_SRCS := $(filter-out $(LKL_EXCLUDE),$(sort $(wildcard $(BASE_SRCS) $(LKL_INCLUDE))))
BASE_OBJS = $(patsubst $(srcdir)/%,%.o,$(basename $(BASE_SRCS)))
ARCH_SRCS := $(filter-out $(LKL_EXCLUDE),$(ARCH_SRCS))
ARCH_OBJS = $(patsubst $(srcdir)/%,%.o,$(basename $(ARCH_SRCS)))
REPLACED_OBJS = $(sort $(subst /$(ARCH)/,/,$(ARCH_OBJS)))
OBJS := $(addprefix obj/, $(filter-out $(REPLACED_OBJS), $(sort $(BASE_OBJS) $(ARCH_OBJS))))
AOBJS := $(OBJS)
LOBJS := $(OBJS:.o=.lo)

all: $(ALL_LIBS) $(ALL_TOOLS)

OBJ_DIRS = $(sort $(patsubst %/,%,$(dir $(ALL_LIBS) $(ALL_TOOLS) $(OBJS) $(LDSO_OBJS) $(GENH) $(GENH_INT))) $(addprefix obj/, crt crt/$(ARCH) include))

$(ALL_LIBS) $(ALL_TOOLS) $(CRT_LIBS:lib/%=obj/crt/%) $(OBJS) $(LOBJS) $(GENH) $(GENH_INT): | $(OBJ_DIRS)

$(OBJ_DIRS):
	mkdir -p $@

install: install-libs install-headers install-tools

clean:
	rm -rf obj lib

distclean: clean
	rm -f config.mak

obj/include/bits/stat.h: $(srcdir)/arch/lkl/bits/stat.h
	cp -f $^ $@

obj/include/bits/alltypes.h: $(srcdir)/arch/$(ARCH)/bits/alltypes.h.in $(srcdir)/include/alltypes.h.in $(srcdir)/tools/mkalltypes.sed
	sed -f $(srcdir)/tools/mkalltypes.sed $(srcdir)/arch/$(ARCH)/bits/alltypes.h.in $(srcdir)/include/alltypes.h.in > $@

obj/src/internal/version.h: $(wildcard $(srcdir)/VERSION $(srcdir)/.git)
	printf '#define VERSION "%s"\n' "$$(cd $(srcdir); sh tools/version.sh)" > $@

obj/src/internal/version.o obj/src/internal/version.lo: obj/src/internal/version.h

obj/crt/rcrt1.o obj/ldso/dlstart.lo obj/ldso/dynlink.lo: $(srcdir)/src/internal/dynlink.h $(srcdir)/arch/$(ARCH)/reloc.h

obj/crt/crt1.o obj/crt/scrt1.o obj/crt/rcrt1.o obj/ldso/dlstart.lo: $(srcdir)/arch/$(ARCH)/crt_arch.h

obj/crt/rcrt1.o: $(srcdir)/ldso/dlstart.c

obj/crt/Scrt1.o obj/crt/rcrt1.o: CFLAGS_ALL += -fPIC

obj/crt/$(ARCH)/crti.o: $(srcdir)/crt/$(ARCH)/crti.s

obj/crt/$(ARCH)/crtn.o: $(srcdir)/crt/$(ARCH)/crtn.s

OPTIMIZE_SRCS = $(wildcard $(OPTIMIZE_GLOBS:%=$(srcdir)/src/%))
$(OPTIMIZE_SRCS:$(srcdir)/%.c=obj/%.o) $(OPTIMIZE_SRCS:$(srcdir)/%.c=obj/%.lo): CFLAGS += -O3

MEMOPS_SRCS = src/string/memcpy.c src/string/memmove.c src/string/memcmp.c src/string/memset.c
$(MEMOPS_SRCS:%.c=obj/%.o) $(MEMOPS_SRCS:%.c=obj/%.lo): CFLAGS_ALL += $(CFLAGS_MEMOPS)

NOSSP_SRCS = $(wildcard crt/*.c) \
	src/env/__libc_start_main.c src/env/__init_tls.c \
	src/env/__stack_chk_fail.c \
	src/thread/__set_thread_area.c src/thread/$(ARCH)/__set_thread_area.c \
	src/string/memset.c src/string/$(ARCH)/memset.c \
	src/string/memcpy.c src/string/$(ARCH)/memcpy.c \
	ldso/dlstart.c ldso/dynlink.c
$(NOSSP_SRCS:%.c=obj/%.o) $(NOSSP_SRCS:%.c=obj/%.lo): CFLAGS_ALL += $(CFLAGS_NOSSP)

$(CRT_LIBS:lib/%=obj/crt/%): CFLAGS_ALL += -DCRT

$(LOBJS) $(LDSO_OBJS): CFLAGS_ALL += -fPIC

CC_CMD = $(CC) $(CFLAGS_ALL) -c -o $@ $<

# Choose invocation of assembler to be used
ifeq ($(ADD_CFI),yes)
	AS_CMD = LC_ALL=C awk -f $(srcdir)/tools/add-cfi.common.awk -f $(srcdir)/tools/add-cfi.$(ARCH).awk $< | $(CC) $(CFLAGS_ALL) -x assembler -c -o $@ -
else
	AS_CMD = $(CC_CMD)
endif

obj/%.o: $(srcdir)/%.s
	$(AS_CMD)

obj/%.o: $(srcdir)/%.S
	$(CC_CMD)

obj/%.o: $(srcdir)/%.c $(GENH) $(IMPH)
	$(CC_CMD)

obj/%.lo: $(srcdir)/%.s
	$(AS_CMD)

obj/%.lo: $(srcdir)/%.S
	$(CC_CMD)

obj/%.lo: $(srcdir)/%.c $(GENH) $(IMPH)
	$(CC_CMD)

lib/libc.so: $(LOBJS) $(LDSO_OBJS)
	$(CC) $(CFLAGS_ALL) $(LDFLAGS_ALL) -nostdlib -shared \
	-Wl,-e,_dlstart -o $@ $(LOBJS) $(LDSO_OBJS) $(LIBCC)

lib/libc.a: $(AOBJS)
	rm -f $@
	$(AR) rc $@ $(AOBJS)
	$(RANLIB) $@

$(EMPTY_LIBS):
	rm -f $@
	$(AR) rc $@

lib/%.o: obj/crt/%.o
	cp $< $@

lib/crti.o: obj/crt/$(ARCH)/crti.o
	cp $< $@

lib/crtn.o: obj/crt/$(ARCH)/crtn.o
	cp $< $@

lib/musl-gcc.specs: $(srcdir)/tools/musl-gcc.specs.sh config.mak
	sh $< "$(includedir)" "$(libdir)" "$(LDSO_PATHNAME)" > $@

obj/musl-gcc: config.mak
	printf '#!/bin/sh\nexec "$${REALGCC:-$(WRAPCC_GCC)}" "$$@" -specs "%s/musl-gcc.specs"\n' "$(libdir)" > $@
	chmod +x $@

obj/%-clang: $(srcdir)/tools/%-clang.in config.mak
	sed -e 's!@CC@!$(WRAPCC_CLANG)!g' -e 's!@PREFIX@!$(prefix)!g' -e 's!@INCDIR@!$(includedir)!g' -e 's!@LIBDIR@!$(libdir)!g' -e 's!@LDSO@!$(LDSO_PATHNAME)!g' $< > $@
	chmod +x $@

$(DESTDIR)$(bindir)/%: obj/%
	$(INSTALL) -D $< $@

$(DESTDIR)$(libdir)/%.so: lib/%.so
	$(INSTALL) -D -m 755 $< $@

$(DESTDIR)$(libdir)/%: lib/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(includedir)/bits/%: $(srcdir)/arch/$(ARCH)/bits/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(includedir)/bits/%: $(srcdir)/arch/generic/bits/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(includedir)/bits/%: obj/include/bits/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(includedir)/bits/stat.h: obj/include/bits/stat.h
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(includedir)/%: $(srcdir)/include/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(LDSO_PATHNAME): $(DESTDIR)$(libdir)/libc.so
	$(INSTALL) -D -l $(libdir)/libc.so $@ || true

install-libs: $(ALL_LIBS:lib/%=$(DESTDIR)$(libdir)/%) $(if $(SHARED_LIBS),$(DESTDIR)$(LDSO_PATHNAME),)

install-headers: $(ALL_INCLUDES:include/%=$(DESTDIR)$(includedir)/%)

install-tools: $(ALL_TOOLS:obj/%=$(DESTDIR)$(bindir)/%)

musl-git-%.tar.gz: .git
	 git --git-dir=$(srcdir)/.git archive --format=tar.gz --prefix=$(patsubst %.tar.gz,%,$@)/ -o $@ $(patsubst musl-git-%.tar.gz,%,$@)

musl-%.tar.gz: .git
	 git --git-dir=$(srcdir)/.git archive --format=tar.gz --prefix=$(patsubst %.tar.gz,%,$@)/ -o $@ v$(patsubst musl-%.tar.gz,%,$@)

.PHONY: all clean install install-libs install-headers install-tools
