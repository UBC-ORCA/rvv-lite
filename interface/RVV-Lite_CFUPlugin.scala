new CfuPlugin(
            stageCount = 1,
            allowZeroLatency = true,
            encodings = List(
              // LOAD-FP
              CfuPluginEncoding (
                instruction = M"-------------------------0100111",
                functionId = List(6 downto 0),
                input2Kind = CfuPlugin.Input2Kind.RS
              ),
              // STORE-FP
              CfuPluginEncoding (
                instruction = M"-------------------------0000111",
                functionId = List(6 downto 0),
                input2Kind = CfuPlugin.Input2Kind.RS
              ),
              // ALU instr - OPIVV, OPFVV, OPMVV, OPIVI
              CfuPluginEncoding (
                instruction = M"-----------------0-------1010111",
                functionId = List(14 downto 12, 6 downto 0),
                input2Kind = CfuPlugin.Input2Kind.RS
              ),
              // ALU instr - OPIVX
              CfuPluginEncoding (
                instruction = M"-----------------100-----1010111",
                functionId = List(14 downto 12, 6 downto 0),
                input2Kind = CfuPlugin.Input2Kind.RS
              ),
              // ALU instr - OPFVF
              CfuPluginEncoding (
                instruction = M"-----------------101-----1010111",
                functionId = List(14 downto 12, 6 downto 0),
                input2Kind = CfuPlugin.Input2Kind.RS
              ),
              // ALU instr - OPMVX
              CfuPluginEncoding (
                instruction = M"-----------------110-----1010111",
                functionId = List(14 downto 12, 6 downto 0),
                input2Kind = CfuPlugin.Input2Kind.RS
              ),
              // CFG instr
              CfuPluginEncoding (
                instruction = M"-----------------111-----1010111",
                functionId = List(14 downto 12, 6 downto 0),
                input2Kind = CfuPlugin.Input2Kind.RS
              ),
              //,
              // CFU I-type
              //CfuPluginEncoding (
              //  instruction = M"-----------------000-----0101011",
              //  functionId = List(23 downto 20),
              //  input2Kind = CfuPlugin.Input2Kind.IMM_I
              //)
            ),
            busParameter = CfuBusParameter(
              CFU_VERSION = 0,
              CFU_INTERFACE_ID_W = 0,
              CFU_FUNCTION_ID_W = 10,
              CFU_REORDER_ID_W = 0,
              CFU_REQ_RESP_ID_W = 0,
              CFU_STATE_INDEX_NUM = 0,
              CFU_INPUTS = 2,
              CFU_INPUT_DATA_W = 32,
              CFU_OUTPUTS = 1,
              CFU_OUTPUT_DATA_W = 32,
              CFU_FLOW_REQ_READY_ALWAYS = false,
              CFU_FLOW_RESP_READY_ALWAYS = argConfig.cfuRespReadyAlways
            )
          )
        )