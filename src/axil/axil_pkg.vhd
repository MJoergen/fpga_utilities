-- ---------------------------------------------------------------------------------------
-- Description:
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package axil_pkg is

  type axil_rec_type is record
    awready : std_logic;
    awvalid : std_logic;
    awaddr  : std_logic_vector;
    wready  : std_logic;
    wvalid  : std_logic;
    wdata   : std_logic_vector;
    wstrb   : std_logic_vector;
    bready  : std_logic;
    bvalid  : std_logic;
    bresp   : std_logic_vector(1 downto 0);
    arready : std_logic;
    arvalid : std_logic;
    araddr  : std_logic_vector;
    rready  : std_logic;
    rvalid  : std_logic;
    rdata   : std_logic_vector;
    rresp   : std_logic_vector(1 downto 0);
  end record axil_rec_type;

  view axil_master_view of axil_rec_type is
    awready : in;
    awvalid : out;
    awaddr  : out;
    wready  : in;
    wvalid  : out;
    wdata   : out;
    wstrb   : out;
    bready  : out;
    bvalid  : in;
    bresp   : in;
    arready : in;
    arvalid : out;
    araddr  : out;
    rready  : out;
    rvalid  : in;
    rdata   : in;
    rresp   : in;
  end view axil_master_view;

  alias axil_slave_view is axil_master_view'converse;

  constant C_AXIL_RESP_OKAY   : std_logic_vector(1 downto 0) := "00";
  constant C_AXIL_RESP_SLVERR : std_logic_vector(1 downto 0) := "10";
  constant C_AXIL_RESP_DECERR : std_logic_vector(1 downto 0) := "11";

end package axil_pkg;

package body axil_pkg is

end package body;

