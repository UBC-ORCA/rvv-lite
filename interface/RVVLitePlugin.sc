import spinal.core._
import vexriscv.plugin.Plugin
import vexriscv.{Stageable, DecoderService, VexRiscv}

class RVVLitePlugin extends Plugin[VexRiscv]{
  //Define the concept of IS_SIMD_ADD signals, which specify if the current instruction is destined for this plugin
  object IS_VECTOR extends Stageable(Bool)

  //Callback to setup the plugin and ask for different services
  override def setup(pipeline: VexRiscv): Unit = {
    import pipeline.config._

    //Retrieve the DecoderService instance
    val decoderService = pipeline.service(classOf[DecoderService])

    //Specify the IS_VECTOR default value when instructions are decoded
    decoderService.addDefault(IS_VECTOR, False)

    //Specify the instruction decoding which should be applied when the instruction matches the 'key' pattern

    // Load instr
    decoderService.add(
      //Bit pattern of vector instructions
      key = M"---------------------0100111",

      //Decoding specification when the 'key' pattern is recognized in the instruction
      List(
        IS_VECTOR                 -> True,
        REGFILE_WRITE_VALID       -> True, //Enable the register file write
        BYPASSABLE_EXECUTE_STAGE  -> True, //Notify the hazard management unit that the instruction result is already accessible in the EXECUTE stage (Bypass ready)
        BYPASSABLE_MEMORY_STAGE   -> True, //Same as above but for the memory stage
        RS1_USE                   -> True, //Notify the hazard management unit that this instruction uses the RS1 value
        RS2_USE                   -> True  //Same as above but for RS2.
      )
    )

    // Store instr
    decoderService.add(
      //Bit pattern of vector instructions
      key = M"---------------------0000111",

      //Decoding specification when the 'key' pattern is recognized in the instruction
      List(
        IS_VECTOR                 -> True,
        REGFILE_WRITE_VALID       -> True, //Enable the register file write
        BYPASSABLE_EXECUTE_STAGE  -> True, //Notify the hazard management unit that the instruction result is already accessible in the EXECUTE stage (Bypass ready)
        BYPASSABLE_MEMORY_STAGE   -> True, //Same as above but for the memory stage
        RS1_USE                   -> True, //Notify the hazard management unit that this instruction uses the RS1 value
        RS2_USE                   -> True  //Same as above but for RS2.
      )
    )


    // ALU instr - OPIVV, OPFVV, OPMVV, OPIVI
    decoderService.add(
      //Bit pattern of vector instructions
      key = M"-------------0-------1010111",

      //Decoding specification when the 'key' pattern is recognized in the instruction
      List(
        IS_VECTOR             -> True,
        REGFILE_WRITE_VALID   -> False, //Enable the register file write
        RS1_USE               -> False,
        RS2_USE               -> False 
      )
    )
    
    // ALU instr - OPIVX
    decoderService.add(
      //Bit pattern of vector instructions
      key = M"-------------100-----1010111",

      //Decoding specification when the 'key' pattern is recognized in the instruction
      List(
        IS_VECTOR             -> True,
        REGFILE_WRITE_VALID   -> False,
        RS1_USE               -> True, //Notify the hazard management unit that this instruction uses the RS1 value
        RS2_USE               -> False
      )
    )
    
    // ALU instr - OPFVF
    decoderService.add(
      //Bit pattern of vector instructions
      key = M"-------------101-----1010111",

      //Decoding specification when the 'key' pattern is recognized in the instruction
      List(
        IS_VECTOR             -> True,
        REGFILE_WRITE_VALID   -> False, //Enable the register file write
        RS1_USE               -> True,  //Notify the hazard management unit that this instruction uses the RS1 value
        RS2_USE               -> False 
      )
    )
    
    // ALU instr - OPMVX
    decoderService.add(
      //Bit pattern of vector instructions
      key = M"-------------110-----1010111",

      //Decoding specification when the 'key' pattern is recognized in the instruction
      List(
        IS_VECTOR             -> True,
        REGFILE_WRITE_VALID   -> False, //Enable the register file write
        RS1_USE               -> True,  //Notify the hazard management unit that this instruction uses the RS1 value
        RS2_USE               -> False 
      )
    )

    // CFG instr
    decoderService.add(
      //Bit pattern of vector instructions
      key = M"-------------111-----1010111",

      //Decoding specification when the 'key' pattern is recognized in the instruction
      List(
        IS_VECTOR             -> True,
        REGFILE_WRITE_VALID   -> True, // Enable the register file write - cfg values are stored in rd
        // BYPASSABLE_EXECUTE_STAGE -> True, //Notify the hazard management unit that the instruction result is already accessible in the EXECUTE stage (Bypass ready)
        // BYPASSABLE_MEMORY_STAGE  -> True, //Same as above but for the memory stage
        RS1_USE               -> True, // Notify the hazard management unit that this instruction uses the RS1 value
        RS2_USE               -> True  // Same as above but for RS2.
      )
    )

  }

  override def build(pipeline: VexRiscv): Unit = {

    // TODO figure out how to redirect these instructions to the IBus Plugin
    // TODO figure out how to get value stored in rs1 (if necessary) and send to IBUS to wait for vector response
    // TODO figure out how to get value back from RVV-Lite to store in register for CFG instructions

    // import pipeline._
    // import pipeline.config._

    //Add a new scope on the execute stage (used to give a name to signals)
    // execute plug new Area {
      //Define some signals used internally by the plugin
      // val rs1 = execute.input(RS1).asUInt
  //     //32 bits UInt value of the regfile[RS1]
  //     val rs2 = execute.input(RS2).asUInt
  //     val rd = UInt(32 bits)

  //     //Do some computations
  //     rd(7 downto 0) := rs1(7 downto 0) + rs2(7 downto 0)
  //     rd(16 downto 8) := rs1(16 downto 8) + rs2(16 downto 8)
  //     rd(23 downto 16) := rs1(23 downto 16) + rs2(23 downto 16)
  //     rd(31 downto 24) := rs1(31 downto 24) + rs2(31 downto 24)

  //     //When the instruction is a SIMD_ADD, write the result into the register file data path.
  //     when(execute.input(IS_VECTOR)) {
  //       execute.output(REGFILE_WRITE_DATA) := rd.asBits
  //     }
  //   }
  // }
}