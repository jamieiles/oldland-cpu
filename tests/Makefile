TESTS := hello

.PHONY:	all clean $(TESTS)

all:	$(TESTS)

clean:	$(TESTS)

$(TESTS):
	$(MAKE) -C $@ -f $(PWD)/Makefile.test TESTNAME=$@ $(MAKECMDGOALS)
