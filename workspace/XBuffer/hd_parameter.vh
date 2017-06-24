`ifndef _hd_parameter_vh_
`define	_hd_parameter_vh_

//size
`define CDB_WIDTH		256
`define MAX_CMDQ_DEPTH	32
`define CMD_DATA_WIDTH	32

// Bit field definition in a CDB
`define	CMD_TYPE			0
`define TAG					1
`define OP_STATUS			2
`define IFQ_INDEX			3
`define LBA					4
`define HOST_BUF_ADDR		8
`define REQ_SIZE			12
`define BUF_OFFSET			14
`define VALID_BITS			15
`define INTERNAL_BUF_BASE	16

// Command Type
`define	BSM_READ			8'h30
`define	BSM_WRITE			8'h40	

// CommandQ Status Transition
`define ST_FREE				8'h00
`define ST_QUEUED2D			8'h01
`define ST_XFER2D			8'h02
`define ST_DONEB			8'h03
`define ST_QUERIED			8'h04
`define ST_DONED			8'h05
`define ST_WAITS			8'h06
`define ST_XFER2H			8'h07

`define ST_QUEUED2S			8'h10
`define ST_ISSUED			8'h20
`define ST_DONES			8'h30

// Status Transition regarding XFER IO buffer
`define XTBM_NOTHING		2'b00
`define XTBM_WRITING		2'b01
`define XTBM_READING		2'b10

// Query command status (1byte) --> Query out information [3:2]
`define QS_NOCMD			2'b00
`define QS_INQUEUE			2'b01
`define QS_INPROCESS		2'b10
`define QS_DONE				2'b11

// General write status (1byte)
// Available 4KB buffers for a write operation [2:0]
`define GWAB_0				3'b000
`define GWAB_1				3'b001
`define GWAB_2				3'b010
`define GWAB_3				3'b011
`define GWAB_4				3'b100

// General read status (1byte)
// Available 4KB buffers for a read operation [2:0]
`define GRAB_0				3'b000
`define GRAB_1				3'b001
`define GRAB_2				3'b010
`define GRAB_3				3'b011
`define GRAB_4				3'b100

`endif