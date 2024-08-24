.PHONY: all
all: rft.txt

%.txt: %.xml
	xml2rfc $<

%.xml: %.md
	kramdown-rfc $< > $@

.PHONY: clean
clean:
	rm -f *.xml *.txt
