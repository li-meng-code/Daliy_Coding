##design and tb files

TB =tb_fifo
DFILES =./../filelist.f
SIM_DIR=simLog


VCOMP =vcs -full64 -sverilog -debug_access+all -kdb -l compile.log
RUN = -l sim.log

comp:
	mkdir -p $(SIM_DIR)
	cd $(SIM_DIR) && $(VCOMP) -f $(DFILES) -top $(TB)

run:comp
	cd $(SIM_DIR) && ./simv $(RUN)

wave:run
	cd $(SIM_DIR)  && nohup verdi -ssf $(TB).fsdb > verdi.log 2>&1 < /dev/null &

clean:
	rm -rf $(SIM_DIR)
