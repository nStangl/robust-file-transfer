.PHONY: rfc
rfc: rft.txt

%.txt: %.xml
	xml2rfc $<

%.xml: %.md
	kramdown-rfc $< > $@

.PHONY: view
view: rft.txt
	less $<

.PHONY: spellcheck
spellcheck: rft.md
	cargo spellcheck --cfg=spellcheck.toml $<

.PHONY: clean
clean:
	rm -f *.xml *.txt
