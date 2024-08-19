---
stand_alone: true
ipr: trust200902
cat: info # Check
submissiontype: IETF
area: Applications
wg: TUM Protocol Design Group 2323

docname: draft-rfcxml-general-template-standard-00
obsoletes: 4711, 4712 # Remove if not needed/Replace
updates: 4710 # Remove if not needed/Replace

title: Robust File Transfer
abbrev: RFT
lang: en
kw: Internet-Draft
# date: 2022-02-02 -- date is filled in automatically by xml2rfc if not given
author:
- role: editor # remove if not true
  ins: N. Stangl
  name: Niklas Stangl
  org: Technical University of Munich
  street: Boltzmannstraße 3
  city: Garching
  code: 85748
  country: DE # use TLD (except UK) or country name
  email: niklas.stangl@tum.de
- role: editor # remove if not true
  ins: J. Pfannschmidt
  name: Johannes Pfannschmidt
  org: Technical University of Munich
  street: Boltzmannstraße 3
  city: Garching
  code: 85748
  country: DE # use TLD (except UK) or country name
  email: johannes.pfannschmidt@cs.tum.edu
- role: editor # remove if not true
  ins: S. Gierens
  name: Sandro-Alessio Gierens
  org: Technical University of Munich
  street: Boltzmannstraße 3
  city: Garching
  code: 85748
  country: DE # use TLD (except UK) or country name
  email: sandro.gierens@tum.de

normative:
  RFC0768: #UDP
  RFC0768: #TCP-CCA
  RFC9000: #QUIC
  RFC3629: #UTF-8 strings
  RFC3385: #CRC32


--- abstract

Robust File Transfer (RFT) is a file-transfer protocol on top of UDP. It is
connection-oriented, stream-parallel and stateful, supporting connection
migration based on connection IDs similar to QUIC. RFT provides point-to-point
operation between a client and a server, enabling IP address migration, flow
control, congestion control, and partial or resumed file transfers using
offsets and lengths.

--- middle

# Introduction {#introduction}

The Protocol Design WG is tasked with standardizing an Application Protocol for
a robust file transfer protocol, RFT. This protocol is intended to provide
point-to-point operation between a client and a server built upon UDP
{{RFC0768}}. It supports connection migration based on connection IDs, in
spirit similar to QUIC {{RFC9000}}, although a bit easier.

RFT is based on UDP, connection-oriented, stateful and uses streams for each
file transfer allowing for parallelization. A point-to-point connection
supports IP address migration, flow control, congestion control and allows to
transfers of a specific length and offset, which can be useful to resume
interrupted transfers or partial transfers. The protocol guarantees in-order
delivery for all packets belonging to a stream. There is no such guarantee for
messages belonging to different streams.

RFT *messages* always consist of a single *Packet Header* and zero or multiple
*Frames* appended continuously on the wire after the packet header without
padding. Frames are either *data frames*, *error frames* or various types of
control frames used for the connection initialization and negotiation, flow
control, congestion control, acknowledgement or handling of commands.

## Keywords {#keywords}

{::boilerplate bcp14-tagged}

## Terms {#terms}

The following terms are used throughout this document:

{:vspace}
Client:
: The endpoint of a connection that initiated it and issues commands over it.

Server:
: The endpoint of a connection that listens for and accepts connections
from clients and answers their commands.

Connection:
: A communication channel between a client and server identified by a
single connection ID unique on both ends.

Packet:
: An RFT datagram send as UDP SDU over a connection containing zero or multiple
frames.

Frame:
: A typed and sized information unit making up (possible with others) the
payload of an RFT packet and usually belonging to a particular stream.

Empty Packet:
: A packet without frames.

Command:
: A typed request initiated by the client to the server, e.g. to initiate
a file transfer, usually opening up a new stream.

Stream:
: A logical channel within a connection that carries frames encapsulating
a particular request i.e. file transfer.

Sender:
: The endpoint sending a packet or frame.

Receiver:
: The endpoint receiving a packet or frame.

## Notation {#notation}

This document defines `U4`, `U8`, `U16`, `U32`, `U64` as unsigned 4-, 8-, 16-,
32-, or 64-bit integers. A `string` is a UTF-8 {{RFC3629}} encoded
zero-terminated string.

Messages are represented in a C struct-like notation. They may be annotated by
C-style comments. All members are laid out continuously on wire, any padding
will be made explicit. Constant values are assigned with a "=".

~~~~ LANGUAGE-REPLACE/DELETE
StructName1 (Length) {
    TypeName1     FieldName1,
    TypeName2     FieldName2 = 0x123,
    TypeName3[4]  FieldName3,
    String        FieldName4,
    StructName2   FieldName5,
}
~~~~
{: title="Message format notation" }

The only scalar types are integer denoted with "U" for unsigned and "I" for
signed integers. Strings are a composite type consisting of the size as "U16"
followed by ASCII-characters. Padding is made explicit via the field name
"Padding" and constant values are assigned with a "=".

To visualize protocol runs we use the following sequence diagram notation:

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |------[CID:1337][ACK, SID:1, FID:3][FLOW, SIZE:1000]------>|
   |                                                           |
   v                                                           v
~~~~
{: title="Sequence diagram notation" }

The individual parts of the packets are enclosed by brackets and only the
relevant values are shown. First we always have the RFT packet header,
followed by zero or multiple frames. See below for more details on the
packet structure.

We use the following abbreviations mostly in diagrams:

| Abbreviation | Meaning                    |
| ------------ | -------------------------- |
| VERS         | Version                    |
| CRC          | Packet checksum            |
| CID          | Connection ID              |
| SID          | Stream ID                  |
| FID          | Frame ID                   |
| CMD          | Command frame              |
| DATA         | Data frame                 |
| ERR          | Error frame                |
| ANSW         | Answer frame               |
| ACK          | Acknowledgement frame      |
| FLOW         | Flow control frame         |
| CHCID        | Connection ID change frame |
| EXIT         | Exit frame                 |
| READ         | Read command               |
| WRITE        | Write command              |
| CHK          | Checksum command           |
| LIST         | List command               |
| STAT         | Stat command               |
| LEN          | Length                     |
| OFF          | Offset                     |
| WIN          | Flow window size           |
| OLD          | Old connection ID          |
| NEW          | New connection ID          |
| MSG          | Message                    |
{: title="Common abbreviations."}

# Overview {#overview}

This section gives a rough overview over the protocol and provides basic
information necessary to follow the detailed description in the following
sections.

The RFT protocol is a simple layer 7 protocol for Robust File Transfer.
It sits on-top of layer 4 with a single RFT packet send as a UDP SDU.
The packet structure is shown in the following figure:

~~~~ LANGUAGE-REPLACE/DELETE
                   +-----------+--------------------------------+
                   | ACK Frame |       Data Frame       |  ...  |
+------------------+-----------+--------------------------------+
| VERS | CID | CRC |                                            |
+------------------+      Payload (zero or multiple frames)     |
|       Header     |                                            |
+------------------+--------------------------------------------+
|                           RFT Packet                          |
+---------------------------------------------------------------+
|                            UDP SDU                            |
+---------------------------------------------------------------+
~~~~
{: title="General packet structure" }

The header contains a version field (VER) for evolvability, as connection
ID (CID) uniquely identifying the connection on both ends, and a
cyclic-redundancy-check (CRC) checksum to validate the packet integrity.

After the header follows the payload which holds one or more RFT frames
inspired by {{RFC9000}}. These serve both for data transfer as well as any
additional logic besides version matching, connection identification, and
packet integrity validation. The most important types are AckFrames for
acknowledging frames based on their frame ID (FID), CommandFrames to issue
commands on the server, and DataFrames to transport data for the commands to
read or write a file. File data in the ReadCommand and WriteCommand as well
as in DataFrames is indexed by byte offset and length making both transfer
recovery and parallel transfers even of different parts of the same file
possible. Each transfer is encapsulated in a stream identified by a stream
ID (SID) allowing for multiplexing multiple transfers over a single connection.

The next sections provides detailed information about connection-related
topics, e.g. establishment, streams, reliability, congestion control and more.
The sections after that explain the message format and framing in more detail,
and lists all the different frame and command types.

# Packet {#packet}

The RFT packet is the basic unit of communication in the protocol. A single
packet takes up the entire UDP payload and is composed of a header and a
its own payload. The packet header is structured as follows:

~~~~ language-REPLACE/DELETE
PacketHeader (64) {
  U8   Version = 1,
  U32  ConnectionId,
  U24  PacketChecksum,
}
~~~~
{: title="Packet header wire format" }

## Version {#version}

To ensure evolvability the packet header contains a 8-bit version field.
Most network protocols never hit a two-digit version number, therefore 8 bit is
deemed sufficient.

The version field identifies the protocol version used by the sender of the
packet. Upon connection establishment server MUST validate that the clients
version is compatible with its own before responding to a handshake request.
A peer SHALL NOT change the protocol version during the lifetime of the
connection, and peers MAY revalidate the version at any time.

As long as RFT is in draft stage with rapid breaking changes the peers SHOULD
strictly match the version number.

## Connection ID {#connection-id}

The 32-bit connection ID uniquely identifies the connection on both ends.
32 bit allows for up to roughly 4 billion connections per UDP port. While
this is not as extensive as QUIC {{RFC9000}}, it is deemed sufficient for a
file transfer protocol. Deployments that require more client connections on a
single server can obviously run multiple protocol instances on different server
ports.

The connection ID is negotiated during connection establishment, which is
discussed in more detail in [Establishment](#establishment). The connection ID
furthermore allows for connection migration, which is discussed in
[Migration](#migration).

## Packet Checksum {#packet-checksum}

The packet checksum is a redundancy check to validate the integrity of packet.
It contains the first 24-bit of the 32-bit cyclic redundancy check (CRC32)
{{RFC3385}} of the entire packet, with the packet checksum itself set to 0.

The length of the checksum is chosen for alignment reasons. Since CRC32 has
a good entropy, "chopping off" 8 bit should not impede its effectiveness, and
also in general make it a suitable choice.

## Payload {#payload}

The payload has a variable size but SHOULD be chosen such, that it does not
produce IP packet fragmentation. So in a typical 1500 Byte MTU network with
a minimal 20 Byte IP and 8 Byte UDP header, followed by the 64 Byte RFT header,
up to 1408 Bytes can be used for the payload.

The payload consists of zero, one, or multiple frames, that build a second
level of packetization in the protocol. The come in different flavors allowing
for flexible state exchange and are discussed in [Frames](#frames).
They also provide the means for multistreaming which is presented in
[Streams](#streams).

# Connection {#connection}

The protocol is connection-based. Connections are identified a singular
connection ID (CID) unique on both sides.

## Establishment {#establishment}

The connection establishment is and via a two-way handshake and is initiated by
the client by sending a packet with connection ID 0. The server responds with
the UDP packet having reversed IP addresses and ports, containing an RFT
packet with the connection ID chosen by the server. The server knows all
IDs of established connections and must make the new one is unique.

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |-------------------------[CID:0]-------------------------->|
   |                                                           |
   |<------------------------[CID:1]---------------------------|
   |                                                           |
   v                                                           v
~~~~
{: title="Sequence diagram of simple connection establishment" }

### Connection ID Negotiation {#connection-id-negotiation}

This simple connection establishment is limited to a single handshake
at a time per UDP source port. If the client wishes to establish multiple over
a single port it can attach a ConnectionIdChangeFrame with a proposed
connection ID for the new one (NEW) and 0 for the old one (OLD). The server
acknowledges this and sends back the handshake response to that connection ID:

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |-----------[CID:0][CHCID, FID:1, OLD:0, NEW:3]------------>|
   |                                                           |
   |<---------------[CID:3][ACK, SID:0, FID:1]-----------------|
   |                                                           |
   v                                                           v
~~~~
{: title="Sequence diagram of successful connection ID proposal" }

In case the proposal is already used for another connection
attaches another ConnectionIdChangeFrame (CHCID) with the new unique connection
ID chosen by the server.

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |-----------[CID:0][CHCID, FID:1, OLD:0, NEW:3]------------>|
   |                                                           |
   |<--[CID:3][ACK, SID:0, FID:1][CHCID, FID:1, OLD:3, NEW:9]--|
   |                                                           |
   |-----------------[CID:9][ACK, SID:0, FID:1]--------------->|
   |                                                           |
   v                                                           v
~~~~
{: title="Sequence diagram of unsuccessful connection ID proposal" }

### Unknown Connection ID {#unknown-connection-id}

When a peer receives a packet for an unknown connection ID it SHOULD simply
ignore it.

## Termination {#termination}

A connection can either be intentionally closed or timeout.

### Tear Down {#tear-down}

If a peer wishes to close the connection it simply sends a Exit frame.

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |-----------------------[CID:5][EXIT]---------------------->|
   |                                                           |
   v                                                           v
~~~~
{: title="Graceful connection tear-down" }

### Timeout {#timeout}

If no packets were received for 5 minutes the connection is considered
dead and the server SHOULD close it. Peers MAY send empty packets (i.e. packets
without frames) to keep the connection alive beyond timeouts.

## Migration {#migration}

A connection is uniquely identified on both ends by the connection ID. As
soon as a peer receives a packet for this connection ID from a different
IP-address port pair, it must change its internal mapping and send all
subsequent packets to the new address. Any packets lost in the meantime
are subjects to retransmission. If a peer has nothing to send, but wishes
to explicitly inform the other end of a migration, the peer MAY simply
send an empty packet (thus a packet without frames).

## Resumption {#resumption}

RFT does not explicitly support connection recovery, but allows for resuming
file transfers by the means of partial reads and writes via the corresponding
offset and length fields in the ReadCommand and WriteCommand frames.

# Reliability {#reliability}

# Frames {#frames}

# Streams {#streams}

# File Transfer {#file-transfer}

# Wire Format {#wire-format}

little endian for numbers

| Frame Type Value | Frame Type                 |
|  0               | Acknowledgement Frame      |
|  1               | Exit Frame                 |
|  2               | Connection ID Change Frame |
|  3               | Flow Control Frame         |
|  4               | Answer Frame               |
|  5               | Error Frame                |
|  6               | Data Frame                 |
|  7               | Read Frame                 |
|  8               | Write Frame                |
|  9               | Checksum Frame             |
| 10               | Stat Frame                 |
| 11               | List Frame                 |
{: title="Frame type definitions."}

~~~~ language-REPLACE/DELETE
PacketHeader (64) {
  U8   Version = 1,
  U32  ConnectionId,
  U24  PacketChecksum,
}
~~~~
{: title="Packet header wire format" }

~~~~ language-REPLACE/DELETE
Packet (len(Header) + len(Frames)) {
  PacketHeader  Header,
  Array[Frame]  Frames,
}
~~~~
{: title="Packet wire format" }

~~~~ language-REPLACE/DELETE
AckFrame (56) {
  U8   TypeID = 0,
  U16  StreamID,
  U32  FrameID,
}
~~~~
{: title="Acknowledgment frame wire format" }

~~~~ language-REPLACE/DELETE
ExitFrame (8) {
  U8  TypeID = 1,
}
~~~~
{: title="Exit frame wire format" }

~~~~ language-REPLACE/DELETE
ConnIdChange (72) {
  U8   TypeID = 2,
  U32  OldConnId,
  U32  NewConnId,
}
~~~~
{: title="Connection ID Change frame wire format" }

~~~~ language-REPLACE/DELETE
FlowControl (40) {
  U8   TypeID = 3,
  U32  WindowSize,
}
~~~~
{: title="Flow control frame wire format" }

~~~~ language-REPLACE/DELETE
AnswerFrame (88 + len(Payload)) {
  U8         TypeID = 4,
  U16        StreamId,
  U32        FrameId,
  U32        CommandFrameId,
  ByteArray  Payload,
}
~~~~
{: title="Answer frame wire format" }

~~~~ language-REPLACE/DELETE
ErrorFrame (56 + len(Message)) {
  U8      TypeID = 5,
  U16     StreamId,
  U32     FrameId,
  U32     CommandFrameId,
  String  Message,
}
~~~~
{: title="Error frame wire format" }

~~~~ language-REPLACE/DELETE
DataFrame (104 + len(Payload)) {
  U8         TypeID = 6,
  U16        StreamId,
  U32        FrameId,
  U48        Offset,
  ByteArray  Payload,
}
~~~~
{: title="Error frame wire format" }

~~~~ language-REPLACE/DELETE
ReadFrame (192 + len(Path)) {
  U8      TypeID = 7,
  U16     StreamId,
  U32     FrameId,
  U7      Reserved = 0,
  Bool    ValidateChecksum,
  U48     Offset,
  U48     Length,
  U32     Checksum,
  String  Path,
}
~~~~
{: title="Read frame wire format" }

~~~~ language-REPLACE/DELETE
WriteFrame (152 + len(Path)) {
  U8      TypeID = 8,
  U16     StreamId,
  U32     FrameId,
  U48     Offset,
  U48     Length,
  String  Path,
}
~~~~
{: title="Write frame wire format" }

~~~~ language-REPLACE/DELETE
ChecksumFrame (56 + len(Path)) {
  U8      TypeID = 9,
  U16     StreamId,
  U32     FrameId,
  String  Path,
}
~~~~
{: title="Checksum frame wire format" }

~~~~ language-REPLACE/DELETE
StatFrame (56 + len(Path)) {
  U8      TypeID = 10,
  U16     StreamId,
  U32     FrameId,
  String  Path,
}
~~~~
{: title="Stat frame wire format" }

~~~~ language-REPLACE/DELETE
ListFrame (56 + len(Path)) {
  U8      TypeID = 11,
  U16     StreamId,
  U32     FrameId,
  String  Path,
}
~~~~
{: title="List frame wire format" }
