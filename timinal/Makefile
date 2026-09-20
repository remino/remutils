PREFIX ?= /usr/local
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec
MANDIR ?= $(PREFIX)/share/man/man1
INSTALL ?= install

.PHONY: install uninstall

install:
	$(INSTALL) -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(LIBEXECDIR)/timinal" "$(DESTDIR)$(MANDIR)"
	$(INSTALL) -m 755 timinal.py "$(DESTDIR)$(LIBEXECDIR)/timinal/timinal.py"
	printf '%s\n' '#!/bin/sh' 'exec python3 "$(LIBEXECDIR)/timinal/timinal.py" "$$@"' > "$(DESTDIR)$(BINDIR)/timinal"
	chmod 755 "$(DESTDIR)$(BINDIR)/timinal"
	$(INSTALL) -m 644 man/timinal.1 "$(DESTDIR)$(MANDIR)/timinal.1"

uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/timinal" "$(DESTDIR)$(MANDIR)/timinal.1"
	rm -rf "$(DESTDIR)$(LIBEXECDIR)/timinal"
