clean:
	rm -f *.tar.gz *.tar.gz.sha256

list:
	find . -depth 1 -type d -print0 | while read -r -d '' dir; do name="$(basename "$dir")"; [ -f "$dir/$name" ] && echo "$name" || true; done

tests name="":
	if [ -n "{{name}}" ]; then \
		bin/script-tests {{name}}; \
	else \
		just tests-all; \
	fi

tests-all:
	bats -r .

version name="":
	if [ -n "{{name}}" ]; then \
		bin/version show "{{name}}/{{name}}"; \
	else \
		just version-all; \
	fi

version-all:
	just list | while read -r name; do \
		printf "%s %s\n" "$name" "$( bin/version show "$name/$name" )"; \
	done
