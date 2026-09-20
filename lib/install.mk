# Shared installation rules for remutils command-line tools.
#
# Each tool's Makefile sets TOOL and the file lists it needs, then includes this
# file. Override PREFIX, DESTDIR, or the directory variables for packaging.

PREFIX ?= /usr/local
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1
LIBDIR ?= $(PREFIX)/lib
LIBEXECDIR ?= $(PREFIX)/libexec
SHAREDIR ?= $(PREFIX)/share
INSTALL ?= install

BINARIES ?=
LIBEXEC_BINARIES ?=
LIBEXEC_FILES ?=
MANPAGES ?=
ALIASES ?=
LIB_FILES ?=
SHARE_FILES ?=
BASH_COMPLETIONS ?=
ZSH_COMPLETIONS ?=
FISH_COMPLETIONS ?=

TOOL_LIBEXECDIR = $(DESTDIR)$(LIBEXECDIR)/$(TOOL)

.PHONY: install uninstall install-after

install:
	@if test -n "$(BINARIES) $(LIBEXEC_BINARIES)"; then \
		$(INSTALL) -d "$(DESTDIR)$(BINDIR)"; \
	fi
	@for binary in $(BINARIES); do \
		$(INSTALL) -m 755 "$$binary" "$(DESTDIR)$(BINDIR)/$$(basename "$$binary")"; \
	done
	@if test -n "$(LIBEXEC_FILES)"; then \
		$(INSTALL) -d "$(TOOL_LIBEXECDIR)"; \
		for file in $(LIBEXEC_FILES); do cp -R "$$file" "$(TOOL_LIBEXECDIR)/"; done; \
	fi
	@for binary in $(LIBEXEC_BINARIES); do \
		ln -sf "$(LIBEXECDIR)/$(TOOL)/$$binary" "$(DESTDIR)$(BINDIR)/$$(basename "$$binary")"; \
	done
	@if test -n "$(MANPAGES)"; then \
		$(INSTALL) -d "$(DESTDIR)$(MANDIR)"; \
		for manpage in $(MANPAGES); do \
			$(INSTALL) -m 644 "$$manpage" "$(DESTDIR)$(MANDIR)/$$(basename "$$manpage")"; \
		done; \
	fi
	@for alias in $(ALIASES); do \
		name="$${alias%%:*}"; target="$${alias#*:}"; \
		ln -sf "$$target" "$(DESTDIR)$(BINDIR)/$$name"; \
	done
	@if test -n "$(LIB_FILES)"; then \
		$(INSTALL) -d "$(DESTDIR)$(LIBDIR)"; \
		for file in $(LIB_FILES); do $(INSTALL) -m 755 "$$file" "$(DESTDIR)$(LIBDIR)/$$(basename "$$file")"; done; \
	fi
	@if test -n "$(SHARE_FILES)"; then \
		$(INSTALL) -d "$(DESTDIR)$(SHAREDIR)/$(TOOL)"; \
		for file in $(SHARE_FILES); do cp -R "$$file" "$(DESTDIR)$(SHAREDIR)/$(TOOL)/"; done; \
	fi
	@if test -n "$(BASH_COMPLETIONS)"; then \
		$(INSTALL) -d "$(DESTDIR)$(SHAREDIR)/bash-completion/completions"; \
		for file in $(BASH_COMPLETIONS); do $(INSTALL) -m 644 "$$file" "$(DESTDIR)$(SHAREDIR)/bash-completion/completions/$$(basename "$$file")"; done; \
	fi
	@if test -n "$(ZSH_COMPLETIONS)"; then \
		$(INSTALL) -d "$(DESTDIR)$(SHAREDIR)/zsh/site-functions"; \
		for file in $(ZSH_COMPLETIONS); do $(INSTALL) -m 644 "$$file" "$(DESTDIR)$(SHAREDIR)/zsh/site-functions/$$(basename "$$file")"; done; \
	fi
	@if test -n "$(FISH_COMPLETIONS)"; then \
		$(INSTALL) -d "$(DESTDIR)$(SHAREDIR)/fish/vendor_completions.d"; \
		for file in $(FISH_COMPLETIONS); do $(INSTALL) -m 644 "$$file" "$(DESTDIR)$(SHAREDIR)/fish/vendor_completions.d/$$(basename "$$file")"; done; \
	fi
	@$(MAKE) --no-print-directory install-after

install-after:

uninstall:
	@for binary in $(BINARIES) $(LIBEXEC_BINARIES); do rm -f "$(DESTDIR)$(BINDIR)/$$(basename "$$binary")"; done
	@for alias in $(ALIASES); do rm -f "$(DESTDIR)$(BINDIR)/$${alias%%:*}"; done
	@for manpage in $(MANPAGES); do rm -f "$(DESTDIR)$(MANDIR)/$$(basename "$$manpage")"; done
	@for file in $(LIB_FILES); do rm -f "$(DESTDIR)$(LIBDIR)/$$(basename "$$file")"; done
	@for file in $(BASH_COMPLETIONS); do rm -f "$(DESTDIR)$(SHAREDIR)/bash-completion/completions/$$(basename "$$file")"; done
	@for file in $(ZSH_COMPLETIONS); do rm -f "$(DESTDIR)$(SHAREDIR)/zsh/site-functions/$$(basename "$$file")"; done
	@for file in $(FISH_COMPLETIONS); do rm -f "$(DESTDIR)$(SHAREDIR)/fish/vendor_completions.d/$$(basename "$$file")"; done
	@if test -n "$(LIBEXEC_FILES)"; then rm -rf "$(TOOL_LIBEXECDIR)"; fi
	@for file in $(SHARE_FILES); do rm -rf "$(DESTDIR)$(SHAREDIR)/$(TOOL)/$$(basename "$$file")"; done
