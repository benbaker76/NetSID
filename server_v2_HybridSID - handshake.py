import serial
import socket, struct
import time

HOST = 'localhost'
PORT = 6581
BAUD = 2000000
COMPORT = 4

# Request commands:
command_list = [ 'FLUSH',
                 'TRY_SET_SID_COUNT',
                 'MUTE',
                 'TRY_RESET',
                 'TRY_DELAY',
                 'TRY_WRITE',
                 'TRY_READ',
                 'GET_VERSION',
                 'TRY_SET_SAMPLING',
                 'TRY_SET_CLOCKING',
                 'GET_CONFIG_COUNT',
                 'GET_CONFIG_INFO',
                 'SET_SID_POSITION',
                 'SET_SID_LEVEL',
                 'TRY_SET_SID_MODEL' ]

# Response:
OK, BUSY, ERR, READ, VERSION, COUNT, INFO = range( 7 )

PHI2 = 985248

def send_OK():
    conn.send( struct.pack( '!B', OK ) )

def send_BUSY():
    conn.send( struct.pack( '!B', BUSY ) )

def send_VERSION():
    conn.send( struct.pack( '!BB', VERSION, 2 ) )

def send_COUNT():
    conn.send( struct.pack( '!BB', COUNT, 2 ) )

def send_INFO( sid_number ):
    MOS_6581 = 0
    MOS_8580 = 1
    sid_list = [ '6581', '8580' ]
    name_template = 'HybridSID %s\x00'
    name = name_template % sid_list[ sid_number ]
    conn.send( struct.pack( '!BB%ss' % len( name ), INFO, MOS_8580, name.encode('utf-8') ) )

class ACID64Closed:
    pass

ser = None
while True:
    while ser is None:
        try:
            ser = serial.Serial( 'COM%s' % COMPORT, timeout=0, baudrate=BAUD)
            print( 'using COM%s' % COMPORT)
            break
        except serial.serialutil.SerialException:
            pass
        else:
            print( 'no serial device found')
            time.sleep( 0.5 )

    s = socket.socket( socket.AF_INET, socket.SOCK_STREAM )
    s.bind( ( HOST, PORT ) )
    print( 'listening on port %s' % PORT)
    s.listen( 1 )
    conn, address = s.accept()
    print( 'connected')

    try:
        status = ''
        paused = 0
        cycles = 0
        byte_count = 0
        previous_time = time.time()
        start = time.time()
        while True:
            ##print( time.time() - start, cycles / float( PHI2 ))

            if paused == 1:
                status = ser.read()
                if len(status) > 0 :
                    if status == b'S':
                        paused = 0
            else:
                data = b''
                while len( data ) < 4:
                    d = conn.recv( 4 - len( data ) )
                    if len( d ) != 0:
                        data += d
                    else:
                        raise ACID64Closed

                command, sid_number, data_length = struct.unpack( '!BBH', data )

                data = b''
                while len( data ) < data_length:
                    d = conn.recv( data_length - len( data ) )
                    if len( d ) != 0:
                        data += d
                    else:
                        raise ACID64Closed

                assert command < len( command_list ), 'Unknown command: command = %s, sid_number = %s, data_length = %s.' % ( command, sid_number, data_length )
                ##print( '%s: #%s, [%s]' % ( command_list[ command ], sid_number, data_length ))

                if command == 0: # FLUSH
                    cycles = 0
                    start = time.time()
                    send_OK()

                elif command == 1: # TRY_SET_SID_COUNT
                    send_OK()

                elif command == 2: # MUTE
                    voice, enable = struct.unpack( '!BB', data )
                    print( '  voice: %s, enable: %s' % ( voice, enable ))
                    send_OK()

                elif command == 3: # TRY_RESET
                    volume_register_value, = struct.unpack( '!B', data )
                    print( '  volume register value: %s' % volume_register_value)
                    send_OK()

                elif command == 4: # TRY_DELAY
                    ##if time.time() - start < cycles / float( PHI2 ):
                    ##    print( 'busy')
                    ##    send_BUSY()
                    ##else:
                    ##    delay, = struct.unpack( '!H', data )
                    ##    cycles += delay
                    ##    print( '  delay: %s' % delay)
                        ser.write( struct.pack( '!sBB', data, 30, 0 ) )
                        send_OK()

                elif command == 5: # TRY_WRITE
                    ##if time.time() - start < cycles / float( PHI2 ):
                    ##    print( 'busy')
                    ##    send_BUSY()
                    ##else:
                    ##    for i in range( 0, data_length, 4 ):
                    ##        delay, register, value = struct.unpack( '!HBB', data[ i : i + 4 ] )
                    ##        cycles += delay
                    ##        ##print( '  delay: %s, register: %s, value: %s' % ( delay, register, value ))
                    ##        ##ser.write( data[ i : i + 4 ] )
                        ser.write( data )
                        status = ser.read()
                        if len(status) > 0 :
                          #if status == b'S':
                          #  paused = 0
                          #  #print( 'START')
                          if status == b'E':
                            paused = 1
                            print( 'FPGA requested pause, buffer full...')
                            #print( '>>>>>>BUSY')
                        send_OK()
                            #print( '>>>>>>OK')
                        byte_count += data_length
                        current_time = time.time()
                        if previous_time + 0.1 < current_time:
                            print( '%s Bytes/s,' % int( byte_count / ( current_time - previous_time ) ), 'block size: %s' % data_length)
                            byte_count = 0
                            previous_time = current_time

                elif command == 6: # TRY_READ
                    assert False, 'not implemented'

                elif command == 7: # GET_VERSION
                    assert data_length == 0
                    send_VERSION()

                elif command == 8: # TRY_SET_SAMPLING
                    resampling_method, = struct.unpack( '!B', data )
                    print( '  resampling method: %s quality' % ( 'low' if resampling_method == 0 else 'high' ))
                    send_OK()

                elif command == 9: # TRY_SET_CLOCKING
                    clock_source_speed, = struct.unpack( '!B', data )
                    print( '  clock source speed: %s' % ( 'PAL' if clock_source_speed == 0 else 'NTSC' ))
                    send_OK()

                elif command == 10: # GET_CONFIG_COUNT
                    send_COUNT()

                elif command == 11: # GET_CONFIG_INFO
                    send_INFO( sid_number )

                elif command == 12: # SET_SID_POSITION
                    position, = struct.unpack( '!B', data )
                    print( '  position: %s' % position)
                    send_OK()

                elif command == 13: # SET_SID_LEVEL
                    assert False, 'not implemented'

                elif command == 14: # TRY_SET_SID_MODEL
                    model, = struct.unpack( '!B', data )
                    print( '  model: %s' % model)
                    send_OK()

    except ACID64Closed:
        print( 'ACID 64 closed')

    except socket.error as text:
        print( 'socket.error:', text)

    except serial.serialutil.SerialTimeoutException:
        conn.close()
        s.close()
        ser = None
        print( 'serial device removed')
        time.sleep( 1 ) # Wait a bit before enumerating the COM ports again.
