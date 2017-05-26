/*
 * xfer_buffer.h
 *
 *  Created on: May 3, 2017
 *      Author: jk
 */

#ifndef XFER_BUFFER_H_
#define XFER_BUFFER_H_

#include <systemc.h>
#include "hd_multiqueue.h"

SC_MODULE(xfer_buffer) {
	sc_in<bool> 					reset;
	// host --> xfer buffer
	sc_in<bool> 					clock_host;
	sc_in<bool> 					host_select;
	sc_in<bool> 					hwrite_enable;
	sc_in<sc_uint<32> > 			buf_address; // obsolete... need to confirm the usage of this channel
	sc_inout<sc_uint<HDATA_WIDTH> >	hostdata_inout;

	// interface command queue --> xfer buffer
	sc_in<bool>						clock_fpga;
	sc_in<bool>						xfer_buf_select;
	sc_in<bool>						mwrite_enable;
	sc_in<sc_uint<32> > 			tbm_address; // 20bit
	sc_out<bool>					xfer_complete;

	// xfer buffer <-> tbm
	sc_out<bool> 					chip_select;
	sc_out<bool> 					write_enable;
	sc_out<sc_uint<MADDR_WIDTH> > 	maddress;
	sc_inout<sc_biguint<MDATA_WIDTH> >	mdata_inout;

	// General status read/write
	sc_in<bool>						gs_select;
	sc_in<bool>						gs_write_enable;
	sc_out<sc_uint<8> >				gs_out;
	sc_out<bool>					gs_out_enable;

	sc_biguint<MDATA_WIDTH>  		rx_buffer[NUM_DATA_WIDTH_FOR_XFER_BUF]; // 32 Bytes (256 bits) x 4KB buffer
	sc_biguint<MDATA_WIDTH> 		tx_buffer[NUM_DATA_WIDTH_FOR_XFER_BUF]; // 32 Bytes (256 bits) x 4KB buffer
	sc_uint<8>	rx_head, rx_tail, tx_head, tx_tail; // 4KB buffer offset
	sc_uint<8>	rx_anum, tx_anum; // the number of available rx/tx buffers.
	sc_mutex	rx_mutex, tx_mutex;
	sc_uint<8>  htoBufOffset, hfromBufOffset; // HOST --> XFER BUF MDATA_WIDTH OFFSET
	sc_uint<8>  mtoBufOffset, mfromBufOffset; // XFER BUF --> TBM  MDATA_WIDTH OFFSET
	sc_uint<8>  htoBufBitOffset, hfromBufBitOffset;
	sc_uint<32>	rx_address, tx_address;
	sc_uint<8>	mxferprocessing; //write data to tbm: 1, read data from tbm: 2

	void core_process(void);
	void tophalf_process(void);
	void bottomhalf_process(void);
	void gs_process(void);

	SC_CTOR(xfer_buffer) {
		SC_METHOD(core_process);
		dont_initialize();
		sensitive << reset;

		SC_THREAD(tophalf_process);
		sensitive << host_select << hwrite_enable << clock_host.pos() << clock_host.neg();

		SC_THREAD(bottomhalf_process);
		sensitive << xfer_buf_select << mwrite_enable << clock_fpga.neg() << clock_fpga.pos();

		SC_THREAD(gs_process);
		sensitive << gs_select << gs_write_enable;

	}
};

void xfer_buffer::core_process(void)
{
	if(reset.read() == 1)
	{
		rx_head = rx_tail = tx_head = tx_tail = 0;
		htoBufOffset = hfromBufOffset = mtoBufOffset = mfromBufOffset = 0;
		htoBufBitOffset = hfromBufBitOffset = 0;
		rx_address = tx_address = 0;
		mxferprocessing = 0;
		rx_anum = tx_anum = BUF_QUEUE_DEPTH; // the number of available rx/tx buffers
	}
}

/*
 * When host tries to transfer data from/to xfer buffer, host already confirm
 * if there are available buffers in xfer buffer.
 */
void xfer_buffer::tophalf_process(void)
{
	sc_uint<32>	tmp_dword;

	while (true)
	{
		wait();

		/*
		Host transfer 32bit data every clock.. xfer_buffer automatially receive/send the data. 
		*/
		if (host_select.read() == 1)
		{
			// host --> xfer_buf
			if (hwrite_enable.read() == 1)
			{
				// buf_address is not required!!.. if you need to implement..
				cout << "rx_head:" << rx_head << ", NUM_DATA_WIDTH_PER_BUF:"<< NUM_DATA_WIDTH_PER_BUF <<",  htoBufOffset:" << htoBufOffset << endl;
				cout << "rx_buffer idx:" << rx_head*NUM_DATA_WIDTH_PER_BUF + htoBufOffset << endl;
				cout << "bit range upper limit:" << HDATA_WIDTH*(htoBufBitOffset + 1) - 1 << endl;
				cout << "bit range lower limit:" << HDATA_WIDTH*(htoBufBitOffset) << endl;
				rx_buffer[(rx_head*NUM_DATA_WIDTH_PER_BUF) + htoBufOffset].range(((HDATA_WIDTH * (htoBufBitOffset+1)) - 1), (HDATA_WIDTH * htoBufBitOffset)) = hostdata_inout.read();
				cout << "xfer_buf>> @" << sc_time_stamp() << ", data: " << hostdata_inout << endl;
		
				htoBufBitOffset++;
				if (htoBufBitOffset == DATA_WIDTH_DIFF) // DATA_WIDTH_DIFF == 8
				{
					htoBufBitOffset = 0;
					htoBufOffset++;
					if (htoBufOffset == NUM_DATA_WIDTH_PER_BUF)
					{
						htoBufOffset = 0;
						rx_mutex.lock();
						rx_anum--;
						rx_mutex.unlock();

						rx_head++;
						if (rx_head == BUF_QUEUE_DEPTH)
						{
							rx_head = 0;
						}
					}
				}
			}
			else {
				// xfer_buf --> host
				if (tx_head == tx_tail)
				{
					// nothing to do
				}
				else
				{
					tmp_dword = tx_buffer[((tx_tail*NUM_DATA_WIDTH_PER_BUF) + hfromBufOffset)].range(((HDATA_WIDTH*(hfromBufBitOffset+1))-1), HDATA_WIDTH * hfromBufBitOffset);

					hostdata_inout = tmp_dword;
					hfromBufBitOffset++;
					if (hfromBufBitOffset == DATA_WIDTH_DIFF)
					{
						hfromBufBitOffset = 0;

						hfromBufOffset++;
						if (hfromBufOffset == NUM_DATA_WIDTH_PER_BUF)
						{
							hfromBufOffset = 0;

							tx_mutex.lock();
							tx_anum++;
							tx_mutex.unlock();

							tx_tail++;
							if (tx_tail == BUF_QUEUE_DEPTH)
							{
								tx_tail = 0;
							}
						}
					}

				}

			}
		}
		else {
			// nothing to do..
		}
		/*
		 * TODO: 1. export the number of ready buffers.
		 */
	} // while-loop
}

void xfer_buffer::bottomhalf_process(void)
{
	while (true)
	{
		wait();

		xfer_complete.write(0);

		if ((mxferprocessing == 0) && (xfer_buf_select.read() == 1))
		{
			// xfer_buf --> tbm
			if (mwrite_enable.read() == 1)
			{
				rx_address = tbm_address.read();
				mxferprocessing = 1;
			}
			// tbm --> xfer_buf
			else
			{
				tx_address = tbm_address.read();
				mxferprocessing = 2;
			}
		}

		// xfer_buf --> tbm
		if (mxferprocessing == 1)
		{
			if (rx_head == rx_tail)
			{
				// nothing to do
			}
			else
			{
				chip_select.write(1);
				write_enable.write(1);
				maddress.write(rx_address); // TODO: revised
				mdata_inout = rx_buffer[((rx_tail * NUM_DATA_WIDTH_PER_BUF) + mfromBufOffset)];

				cout << "@" << sc_time_stamp() << ", offset by 32B: " << mfromBufOffset << endl;

				mfromBufOffset++;
				if (mfromBufOffset == NUM_DATA_WIDTH_PER_BUF)
				{
					mfromBufOffset = 0;
					mxferprocessing = 0;
					xfer_complete.write(1);
					rx_tail++;
					if(rx_tail == BUF_QUEUE_DEPTH)
					{
						rx_tail = 0;
					}

					rx_mutex.lock();
					rx_anum++;
					rx_mutex.unlock();

				}
				rx_address = rx_address + 32; // increase the address by 32 bytes (256 bits)...

			}
		}
		// tbm --> xfer_buf
		else if (mxferprocessing == 2)
		{
			if (tx_anum == 0)
			{
				// nothing to do..

			}
			else
			{
				chip_select.write(1);
				write_enable.write(0);
				maddress.write(tx_address);
				tx_buffer[((tx_head * NUM_DATA_WIDTH_PER_BUF) + mtoBufOffset)] = mdata_inout.read();
				mtoBufOffset++;
				if (mtoBufOffset == NUM_DATA_WIDTH_PER_BUF)
				{
					mtoBufOffset = 0;
					mxferprocessing =0;
					xfer_complete.write(1);

					tx_head++;
					if(tx_head == BUF_QUEUE_DEPTH)
					{
						tx_head = 0;
					}

					tx_mutex.lock();
					tx_anum--;
					tx_mutex.unlock();
				}
				tx_address = tx_address + 32;
			}
		}
	}
}

void xfer_buffer::gs_process(void)
{
	while (true)
	{
		wait();
		gs_out_enable.write(0);

		if (gs_select.read() == 1)
		{
			if (gs_write_enable.read() == 1)
			{
				gs_out_enable.write(1);
				gs_out.write(rx_anum);
			}
			else
			{
				gs_out_enable.write(1);
				gs_out.write(tx_anum);
			}
		}
	}
}

#endif /* XFER_BUFFER_H_ */