PREFIX ?= /usr/local
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec
MANDIR ?= $(PREFIX)/share/man/man1
INSTALL ?= install

.PHONY: install uninstall

install:
	$(INSTALL) -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(LIBEXECDIR)" "$(DESTDIR)$(MANDIR)"
	$(INSTALL) -m 755 mkprj "$(DESTDIR)$(BINDIR)/mkprj"
	cp -R lib templates "$(DESTDIR)$(LIBEXECDIR)/"
	$(INSTALL) -m 644 man/mkprj.1 "$(DESTDIR)$(MANDIR)/mkprj.1"

uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/mkprj" "$(DESTDIR)$(MANDIR)/mkprj.1"
	rm -rf "$(DESTDIR)$(LIBEXECDIR)/lib" "$(DESTDIR)$(LIBEXECDIR)/templates"
