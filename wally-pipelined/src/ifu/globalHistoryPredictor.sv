///////////////////////////////////////////
// globalHistoryPredictor.sv
//
// Written: Shreya Sanghai
// Email: ssanghai@hmc.edu
// Created: March 16, 2021
// Modified: 
//
// Purpose: Global History Branch predictor with parameterized global history register
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT 
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

`include "wally-config.vh"

module globalHistoryPredictor
  #(parameter int k = 10
    )
  (input logic clk,
   input logic 		   reset,
   input logic 		   StallF, StallD, StallE, FlushF, FlushD, FlushE,
   input logic [`XLEN-1:0] LookUpPC,
   output logic [1:0] 	   Prediction,
   // update
   input logic [`XLEN-1:0] UpdatePC,
   input logic 		   UpdateEN, PCSrcE,
   input logic SpeculativeUpdateEn, BPPredDirWrongE,
   input logic [1:0] 	   UpdatePrediction
  
   );
  logic [k-1:0] 	   GHRF, GHRFNext, GHRD, GHRE, GHRLookup;

  logic 		   FlushedD, FlushedE;
  

  // if the prediction is wrong we need to restore the ghr.
  assign GHRFNext = BPPredDirWrongE ? {PCSrcE, GHRE[k-1:1]} : 
		    {Prediction[1], GHRF[k-1:1]};

  flopenr #(k) GlobalHistoryRegister(.clk(clk),
				     .reset(reset),
				     .en((UpdateEN & BPPredDirWrongE) | (SpeculativeUpdateEn)),
				     .d(GHRFNext),
				     .q(GHRF));

  // if actively updating the GHR at the time of prediction we want to us
  // GHRFNext as the lookup rather than GHRF.

  assign GHRLookup = UpdateEN ? GHRFNext : GHRF;

  // Make Prediction by reading the correct address in the PHT and also update the new address in the PHT 
  SRAM2P1R1W #(k, 2) PHT(.clk(clk),
			 .reset(reset),
			 .RA1(GHRF),
			 .RD1(Prediction),
			 .REN1(~StallF),
			 .WA1(GHRE),
			 .WD1(UpdatePrediction),
			 .WEN1(UpdateEN),
			 .BitWEN1(2'b11));

  flopenr #(k) GlobalHistoryRegisterD(.clk(clk),
				     .reset(reset),
				     .en(~StallD & ~FlushedE),
				     .d(GHRF),
				     .q(GHRD));

  flopenr #(k) GlobalHistoryRegisterE(.clk(clk),
				     .reset(reset),
				     .en(~StallE & ~ FlushedE),
				     .d(GHRD),
				     .q(GHRE));


  flopenr #(1) flushedDReg(.clk(clk),
			   .reset(reset),
			   .en(~StallD),
			   .d(FlushD),
			   .q(FlushedD));

  flopenr #(1) flushedEReg(.clk(clk),
			   .reset(reset),
			   .en(~StallE),
			   .d(FlushE | FlushedD),
			   .q(FlushedE));
    

endmodule
