# robust-file-transfer

# High-Level Design Differences

## Commonalities

- multiple frames within a packet
- each frame has a type
- different frame formats depending on type (+ "presence") bits
- transmissions can be resumed by setting an initial offset
- 

## Open for Discussion & TODOs

- ConnectionID vs IP-Port Tuple (IP Address, Port)
    - IPP limits server to one connection per port
    - what happens if Server migrates connection?

- Overarching packet Header vs or just Frames
    - Single Header is easier to implement --> no big difference
    - Packet Header + Frames is easier to extend

- Checksum/Verification

## Decisions we made

- ConnectionID
    - field in global per-packet header

- Packet level checksum: CRC-32 (maybe just parts of it)
    - checksum of whole packet (header + payload), header.checksum = 0

- File level checksum: (optionally)
    - make checksum commands s.t. the handling of the file checksum is left to the user
    - allows to leave it out for performance in case it does not matter
    - allows to calculating it in the beginning if the user wants it

- Stream ID or not?
    - u8 for stream id
    - field in every frame header
    - stream IDs unique within ConnectionID connection


## Headers

- Global Header
    - u8 version
    - u32 connectionID
    - u20 Checksum
    - (u8 Number of frames)

- Frames
    - u8 type
    - Frame ID (unique within stream)
    - other fields are type dependant
    - stream ID for everything except flow / exit

- Frame types
    - Commands
        - read [path, offset, length, checksum]
        - checksum [path]
        - (write) [path, offset, length]
        - (list) [path]
        - (stat) [path]
    - error [Frame ID, error code]
    - data [offset, length]
    - ack [Frame ID] //cumulative
    - flow control [window size]
    - (response (to command)) [frameID]
    - exit
