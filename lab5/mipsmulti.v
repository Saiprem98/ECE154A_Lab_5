module controller(input  reg clk, reset,
                  input  reg [5:0] op, funct,
                  input  reg zero,
                  output wire pcen, memwrite, irwrite, regwrite,
                  output wire alusrca, iord, memtoreg, regdst,
                  output wire [1:0] alusrcb, pcsrc,
                  output wire [2:0] alucontrol);

  wire [1:0] aluop;
  wire       branch, pcwrite;

  // maindec module instantiation
  maindec md(clk, reset, op,
             pcwrite, memwrite, irwrite, regwrite,
             alusrca, branch, iord, memtoreg, regdst, 
             alusrcb, pcsrc, aluop);
  // alu module instantiation
  aludec  ad(funct, aluop, alucontrol);

  // have a pc enable to get signal from zero and branch
  assign pcen = pcwrite | branch & zero;
 
endmodule

// maindec module implementation
module maindec(input  reg clk, reset, 
               input  reg [5:0] op, 
               output wire pcwrite, memwrite, irwrite, regwrite,
               output wire alusrca, branch, iord, memtoreg, regdst,
               output wire [1:0] alusrcb, pcsrc,
               output wire [1:0] aluop);


// have all the state from 0 -> 12
  parameter   FETCH   = 4'b0000; 
  parameter   DECODE  = 4'b0001; 
  parameter   MEMADR  = 4'b0010;	
  parameter   MEMRD   = 4'b0011;	
  parameter   MEMWB   = 4'b0100;	
  parameter   MEMWR   = 4'b0101;	
  parameter   RTYPEEX = 4'b0110;	
  parameter   RTYPEWB = 4'b0111;	
  parameter   BEQEX   = 4'b1000;	
  parameter   ADDIEX  = 4'b1001;	
  parameter   ADDIWB  = 4'b1010;	
  parameter   JEX     = 4'b1011;	
// depend of 4'b input

// have opcodes for lw,sw,r, beq,addi,j
  parameter   LW      = 6'b100011;	
  parameter   SW      = 6'b101011;	
  parameter   RTYPE   = 6'b000000;	
  parameter   BEQ     = 6'b000100;	
  parameter   ADDI    = 6'b001000;	
  parameter   J       = 6'b000010;	
// have 6'b determine diff opcodes 

  reg [3:0]  state, nextstate;
  reg [14:0] controls;

 
  always @(posedge clk or posedge reset)			
    if(reset) state <= FETCH; // fetch at reset
    else state <= nextstate;



  // State fetch logic 
  always @*
    case(state)
      FETCH:   nextstate <= DECODE;
        // State fetch logic 
      DECODE:  case(op)
                 LW:      nextstate <= MEMADR;
                 SW:      nextstate <= MEMADR;
                 RTYPE:   nextstate <= RTYPEEX;
                 BEQ:     nextstate <= BEQEX;
                 ADDI:    nextstate <= ADDIEX;
                 J:       nextstate <= JEX;
                 default: nextstate <= 4'bx; 
               endcase

      MEMADR: case(op)
                 LW:      nextstate <= MEMRD;
                 SW:      nextstate <= MEMWR;
                 default: nextstate <= 4'bx;
               endcase
      MEMRD:   nextstate <= MEMWB;
      MEMWB:   nextstate <= FETCH;
      MEMWR:   nextstate <= FETCH;
      RTYPEEX: nextstate <= RTYPEWB;
      RTYPEWB: nextstate <= FETCH;
      BEQEX:   nextstate <= FETCH;
      ADDIEX:  nextstate <= ADDIWB;
      ADDIWB:  nextstate <= FETCH;
      JEX:     nextstate <= FETCH;
      default: nextstate <= 4'bx; 
    endcase

  
  assign {pcwrite, memwrite, irwrite, regwrite, 
          alusrca, branch, iord, memtoreg, regdst,
          alusrcb, pcsrc, aluop} = controls;


  always @*
    case(state)
      FETCH:   controls <= 15'h5010; // state s0
      DECODE:  controls <= 15'h0030; // state s1
      MEMADR:  controls <= 15'h0420; // state s2
      MEMRD:   controls <= 15'h0100; // state s3
      MEMWB:   controls <= 15'h0880; // state s4
      MEMWR:   controls <= 15'h2100; // state s5
      RTYPEEX: controls <= 15'h0402; // state s6
      RTYPEWB: controls <= 15'h0840; // state s7
      BEQEX:   controls <= 15'h0605; // state s8
      ADDIEX:  controls <= 15'h0420; // state s9
      ADDIWB:  controls <= 15'h0800; // state s10
      JEX:     controls <= 15'h4008; // state s11
      default: controls <= 15'hxxxx; // state XXX
    endcase
endmodule

// aluedec imlementation 
module aludec(input  reg [5:0] funct,
              input  reg [1:0] aluop,
              output reg [2:0] alucontrol);

  always @(*)
    case(aluop)
      2'b00: alucontrol <= 3'b010;  // add
      2'b01: alucontrol <= 3'b110;  // sub
      default: case(funct)          // RTYPE
          6'b100000: alucontrol <= 3'b010; // ADD
          6'b100010: alucontrol <= 3'b110; // SUB
          6'b100100: alucontrol <= 3'b000; // AND
          6'b100101: alucontrol <= 3'b001; // OR
          6'b101010: alucontrol <= 3'b111; // SLT
          default:   alucontrol <= 3'bxxx; // ???
        endcase
    endcase

endmodule

// data path implementation 
module datapath(input reg        clk, reset,
                input wire        pcen, irwrite, regwrite,
                input wire         alusrca, iord, memtoreg, regdst,
                input wire  [1:0]  alusrcb, pcsrc, 
                input wire  [2:0]  alucontrol,
                output wire [5:0]  op, funct,
                output wire        zero,
                output wire [31:0] adr, writedata, 
                input wire  [31:0] readdata);

  wire [4:0]  writereg;
  wire [31:0] pcnext, pc;
  wire [31:0] instr, data, srca, srcb;
  wire [31:0] a;
  wire [31:0] aluresult, aluout;
  wire [31:0] signimm;   
  wire [31:0] signimmsh;	
  wire [31:0] wd3, rd1, rd2;

  assign op = instr[31:26]; // op
  assign funct = instr[5:0]; // controller 
//module flopenr #(parameter WIDTH = 8)
//               (input  logic             clk, reset,
//                 input  logic             en,
//                 input  logic [WIDTH-1:0] d, 
//                output logic [WIDTH-1:0] q);
  flopenr #(32) pcreg(clk, reset, pcen, pcnext, pc);

//module mux2 #(parameter WIDTH = 8)
//             (input  logic [WIDTH-1:0] d0, d1, 
//              input  logic             s, 
//              output logic [WIDTH-1:0] y);
  mux2    #(32) adrmux(pc, aluout, iord, adr);
  flopenr #(32) instrreg(clk, reset, irwrite, readdata, instr);
  flopr   #(32) datareg(clk, reset, readdata, data);
  mux2    #(5)  regdstmux(instr[20:16], instr[15:11], regdst, writereg);
  mux2    #(32) wdmux(aluout, data, memtoreg, wd3);
  regfile       rf(clk, regwrite, instr[25:21], instr[20:16], writereg, wd3, rd1, rd2);
  signext       se(instr[15:0], signimm);
  sl2           immsh(signimm, signimmsh);
  flopr   #(32) areg(clk, reset, rd1, a);
  flopr   #(32) breg(clk, reset, rd2, writedata);
  mux2    #(32) srcamux(pc, a, alusrca, srca);
  mux4    #(32) srcbmux(writedata, 32'b100, signimm, signimmsh, alusrcb, srcb);
  alu           alu(srca, srcb, alucontrol, aluresult, zero);
  flopr   #(32) alureg(clk, reset, aluresult, aluout);
  mux3    #(32) pcmux(aluresult, aluout, {pc[31:28], instr[25:0], 2'b00}, pcsrc, pcnext);
endmodule
