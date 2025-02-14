
INSTALL = /usr/local/bin

install: md5index
	@[ -e $(INSTALL)/$< -o -L $(INSTALL)/$< ] && sudo rm $(INSTALL)/$<
	@sudo cp $< $(INSTALL)/$<
	@sudo chmod +x $(INSTALL)/$<

test: finddups.py
	./finddups.py --debug --verbose --interactive --process /srv/drv2 --skip --test --always --save /tmp/file_sums.txt
