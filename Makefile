
INSTALL = /usr/local/bin

install: md5index
	@echo Installing...
	@[ -e $(INSTALL)/$< -o -L $(INSTALL)/$< ] && sudo rm $(INSTALL)/$<
	@sudo cp $< $(INSTALL)/$<
	@sudo chmod +x $(INSTALL)/$<
