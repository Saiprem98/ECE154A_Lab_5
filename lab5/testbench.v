module testbench();

  logic        clk;
  logic        reset;

  logic [5:0]  op, funct; 
  logic [2:0]  alucontrol;
  logic [1:0]  alusrcb, pcsrc;
  logic        zero, pcen, memwrite, irwrite, regwrite;
  logic        alusrca, iord, memotreg, regdst;


  // opcodes & funct   
  parameter   LW      = 6'b100011;	
  parameter   SW      = 6'b101011;	
  parameter   RTYPE   = 6'b000000;	
  parameter   BEQ     = 6'b000100;	
  parameter   ADDI    = 6'b001000;	
  parameter   J       = 6'b000010;	
  parameter   ADD     = 6'b100000;  
  parameter   SUB     = 6'b100010;  
  parameter   AND     = 6'b100100;  
  parameter   OR      = 6'b100101; 
  parameter   SLT     = 6'b101010;  

  controller dut(clk, reset, op, funct, zero, pcen, memwrite, irwrite, regwrite,
                 alusrca, iord, memtoreg, regdst, alusrcb, pcsrc, alucontrol);
  
  always
    begin
      clk <= 1; # 5; clk <= 0; # 5;
    end

  initial
    begin
      reset <= 1; # 12; reset <= 0;
     
      op = LW; funct = 6'bx; zero = 1'bx;
      #50; 

      op = SW; funct = 6'bx; zero = 1'bx;
      #40; 

      op = RTYPE; funct = ADD; zero = 1'bx;
      #40; 

      op = RTYPE; funct = SUB; zero = 1'bx;
      #40;

      op = RTYPE; funct = AND; zero = 1'bx;
      #40;

      op = RTYPE; funct = OR; zero = 1'bx;
      #40; 

      op = RTYPE; funct = SLT; zero = 1'bx;
      #40; 

      op = BEQ; funct = 6'bx; zero = 1'b1;
      #30;

      op = BEQ; funct = 6'bx; zero = 1'b0;
      #30; 

      op = ADDI; funct = 6'bx; zero = 1'bx;
      #40;

      op = J; funct = 6'bx; zero = 1'bx;
      #30; 

    end

endmodule
