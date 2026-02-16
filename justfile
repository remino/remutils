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

format name="":
	if [ -n "{{name}}" ]; then \
		just format-all "{{name}}"; \
	else \
		just format-all .; \
	fi

format-all dir=".":
	prettier --ignore-unknown --write "{{dir}}"
	shfmt -w "{{dir}}"

lint name="":
	if [ -n "{{name}}" ]; then \
		just lint-all "{{name}}"; \
	else \
		just lint-all .; \
	fi

lint-all dir=".":
	prettier --ignore-unknown --check "{{dir}}"
	shfmt -d "{{dir}}"

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
