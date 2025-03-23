.POSIX:
PREFIX = ${HOME}/.local
.PHONY: install uninstall
NAME = dld

$(NAME):
	cp dld.sh $(NAME)

install: $(NAME)
	mkdir -p ${DESTDIR}${PREFIX}/bin
	chmod 755 $(NAME)
	cp -vf $(NAME) ${DESTDIR}${PREFIX}/bin/$(NAME)
	rm -f $(NAME)
uninstall:
	rm -vf ${DESTDIR}${PREFIX}/bin/$(NAME)
clean:
	rm -vrf $(NAME)

