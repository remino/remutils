clean:
	rm -f *.tar.gz *.tar.gz.sha256

list:
	find . -depth 1 -type d -print0 | while read -r -d '' dir; do [ -f "$dir/$(basename "$dir")" ] && echo "$dir" || true; done
