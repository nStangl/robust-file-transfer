.PHONY: all
all: rft.txt rft.html rft.pdf

%.txt %.html %.pdf: %.xml
	xml2rfc --v3 --text --html --pdf $<

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
