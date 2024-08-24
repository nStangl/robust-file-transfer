.PHONY: txt
txt: rft.txt

%.txt: %.xml
	xml2rfc $<

.PHONY: html
html: rft.html

%.html: %.xml
	xml2rfc $< --html

.PHONY: pdf
pdf: rft.pdf

%.pdf: %.xml
	xml2rfc $< --pdf

.PHONY: xml
xml: rft.xml

%.xml: %.md
	kramdown-rfc $< > $@

.PHONY: view
view: view-txt

.PHONY: view-txt
view-txt: rft.txt
	less $<

.PHONY: view-html
view-html: rft.html
	chromium $<

.PHONY: view-pdf
view-pdf: rft.pdf
	evince $<

.PHONY: spellcheck
spellcheck: rft.md
	cargo spellcheck --cfg=spellcheck.toml $<

.PHONY: clean
clean:
	rm -f *.xml *.txt *.html *.pdf
