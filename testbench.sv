`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.07.2026 14:34:38
// Design Name: 
// Module Name: testbench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns/1ps

module tb_cache_controller;

logic clk;
logic reset;

logic        cpu_read;
logic        cpu_write;
logic [31:0] cpu_addr;
logic [31:0] cpu_wdata;

logic [31:0] cpu_rdata;
logic        cpu_ready;

integer pass_count;
integer fail_count;


cache_controller dut(
    .clk(clk),
    .reset(reset),

    .cpu_read(cpu_read),
    .cpu_write(cpu_write),
    .cpu_addr(cpu_addr),
    .cpu_wdata(cpu_wdata),

    .cpu_rdata(cpu_rdata),
    .cpu_ready(cpu_ready)
);


initial begin
    clk = 0;
    forever #5 clk = ~clk;
end


// Expected memory model


function automatic [31:0] expected_mem_data(
    input [31:0] addr
);
begin
    expected_mem_data = (addr >> 2) + 100;
end
endfunction


// READ TASK


task automatic do_read(
    input [31:0] addr,
    input [31:0] expected
);
begin

    @(posedge clk);

    cpu_addr  <= addr;
    cpu_read  <= 1;
    cpu_write <= 0;

    @(posedge clk);

    cpu_read <= 0;

    wait(cpu_ready == 1);

    if(cpu_rdata === expected)
    begin
        pass_count++;

        $display("[%0t] PASS READ  addr=%0d expected=%0d got=%0d",
                 $time, addr, expected, cpu_rdata);
    end
    else
    begin
        fail_count++;

        $display("[%0t] FAIL READ  addr=%0d expected=%0d got=%0d",
                 $time, addr, expected, cpu_rdata);
    end

    @(posedge clk);

end
endtask


// WRITE TASK


task automatic do_write(
    input [31:0] addr,
    input [31:0] data
);
begin

    @(posedge clk);

    cpu_addr  <= addr;
    cpu_wdata <= data;

    cpu_write <= 1;
    cpu_read  <= 0;

    @(posedge clk);

    cpu_write <= 0;

    wait(cpu_ready == 1);

    pass_count++;

    $display("[%0t] WRITE addr=%0d data=%0d",
             $time, addr, data);

    @(posedge clk);

end
endtask


// TEST SEQUENCE


initial begin

    cpu_read  = 0;
    cpu_write = 0;
    cpu_addr  = 0;
    cpu_wdata = 0;

    pass_count = 0;
    fail_count = 0;

    
    // RESET
    

    reset = 1;
    repeat(5) @(posedge clk);
    reset = 0;

   
    // TEST 1 : Read Miss
   
    do_read(0,100);

    
    // TEST 2 : Read Hit
   

    do_read(0,100);

    
    // TEST 3 : Write Hit
    
    do_write(0,999);

    do_read(0,999);

    
    // TEST 4 : Fill all 4 ways of set 0
    
    do_read(16,104);
    do_read(32,108);
    do_read(48,112);

   
    // TEST 5 : Change LRU ordering
    

    do_read(16,104);
    do_read(32,108);

    
    // TEST 6 : Force replacement
    

    do_read(64,116);

    
    // TEST 7 : Verify dirty write-back
    

    do_read(0,999);

    
    // Force eviction of address 0
   
    do_read(80,120);
    do_read(96,124);
    do_read(112,128);
    do_read(128,132);

    
    // Verify memory actually received write-back
   
    if(dut.MEM.memory[0] == 999)
    begin
        pass_count++;

        $display("[%0t] PASS WRITEBACK memory[0]=%0d",
                 $time,
                 dut.MEM.memory[0]);
    end
    else
    begin
        fail_count++;

        $display("[%0t] FAIL WRITEBACK expected=999 got=%0d",
                 $time,
                 dut.MEM.memory[0]);
    end

    

    $display("");
    $display("=========================================");
    $display("Verification Summary");
    $display("=========================================");
    $display("PASS COUNT = %0d", pass_count);
    $display("FAIL COUNT = %0d", fail_count);

    if(fail_count == 0)
        $display("FINAL RESULT : TEST PASSED");
    else
        $display("FINAL RESULT : TEST FAILED");

    $display("=========================================");

    #50;
    $finish;

end

endmodule
