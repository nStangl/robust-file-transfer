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
  ins: S. A. Gierens
  name: Sandro-Alessio Gierens
  org: Technical University of Munich
  street: Boltzmannstraße 3
  city: Garching
  code: 85748
  country: DE # use TLD (except UK) or country name
  email: sandro.gierens@tum.de
- role: editor # remove if not true
  ins: D. Rentz
  name: Désirée Rentz
  org: Technical University of Munich
  street: Boltzmannstraße 3
  city: Garching
  code: 85748
  country: DE # use TLD (except UK) or country name
  email: desiree.rentz@tum.de
- role: editor # remove if not true
  ins: Y. E. Nacar
  name: Yusuf Erdem Nacar
  org: Technical University of Munich
  street: Boltzmannstraße 3
  city: Garching
  code: 85748
  country: DE # use TLD (except UK) or country name
  email: yusuferdem.nacar@tum.de
- role: editor # remove if not true
  ins: I. Gustafsson
  name: Isak Gustafsson
  org: Technical University of Munich
  street: Boltzmannstraße 3
  city: Garching
  code: 85748
  country: DE # use TLD (except UK) or country name
  email: go68wuy@mytum.de

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

To exemplify a actual message example we use the following notation
omitting type names and again making use of "=":

~~~~ LANGUAGE-REPLACE/DELETE
StructName1 {
    FieldName1  = 0,
    FieldName2  = 0x123,
    FieldName3  = [1, 2, 3, 4],
    FieldName4  = "Hello",
    FieldName5  = { ... },
    Padding     = 0,
}
~~~~
{: title="Filled message format notation" }

To visualize protocol runs we use the following sequence diagram notation:

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |------[CID:1337, PID: 2][ACK, PID:3][FLOW, SIZE:1000]----->|
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
| CID          | Connection ID              |
| PID          | Packet ID                  |
| CRC          | Packet checksum            |
| SID          | Stream ID                  |
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
                         +-----------+------------------+-------+
                         | ACK Frame |    Data Frame    |  ...  |
+------+-----+-----+-----+-----------+------------------+-------+
| VERS | CID | PID | CRC |                                      |
+------+-----+-----+-----+    Payload (zero/one/many frames)    |
|       Header           |                                      |
+------------------------+--------------------------------------+
|                           RFT Packet                          |
+---------------------------------------------------------------+
|                            UDP SDU                            |
+---------------------------------------------------------------+
~~~~
{: title="General packet structure" }

The header contains a version field (VER) for evolvability, as connection
ID (CID) uniquely identifying the connection on both ends, a packet ID (PID)
identifying the packet within the connection and a cyclic-redundancy-check
(CRC) checksum to validate the packet integrity.

After the header follows the payload which holds one or more RFT frames
inspired by {{RFC9000}}. These serve both for data transfer as well as any
additional logic besides version matching, connection identification, and
packet integrity validation. The most important types are AckFrames for
acknowledging packets based on their packet ID (PID), command frames to issue
commands on the server, and DataFrames to transport data for the commands to
read or write a file. File data in the ReadFrame and WriteFrame as well
as in DataFrames is indexed by byte offset and length making both transfer
recovery and parallel transfers even of different parts of the same file
possible. Each transfer is encapsulated in a stream identified by a stream
ID (SID) allowing for multiplexing multiple transfers over a single connection.

The next sections provides detailed information about connection-related
topics, e.g. establishment, streams, reliability, congestion control and more.
The sections after that explain the message format and framing in more detail,
and lists all the different frame and command types.

# Packet {#packet}

The RFT packet is the basic transport unit in the protocol. A single
packet takes up the entire UDP payload and is composed of a header and a
its own payload. The packet header is structured as follows:

~~~~ language-REPLACE/DELETE
PacketHeader (64) {
  U8   Version = 1,
  U32  ConnectionId,
  U32  PacketId,
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
connection, and peers MAY re-validate the version at any time.

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

## Packet ID {#packet-id}

The 32-bit packet ID uniquely identifies a packet in one direction of the
connection. Each peer maintains a counter starting at 1 that is incremented
for each packet they send to the other side. The uniqueness only holds up
to wrap-around, and implementations are REQUIRED to handle this properly.
With a 32-bit ID and up to 1500 Byte packets, this means roughly 6 TByte of
data can be transferred before a wrap-around occurs. Even with a
state-of-the-art 1 Tbit/s link, this would take 48 seconds which is deemed
sufficient in comparison to timeouts and other protocol mechanisms.

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
PID|                                                           |PID
---|                                                           |---
 1 |----------------------[CID:0, PID:1]---------------------->|
   |<---------------------[CID:1, PID:1]-----------------------| 1
 2 |-------------------[CID:1, PID:2][...]-------------------->|
   |<------------------[CID:1, PID:2][...]---------------------| 2
 3 |-------------------[CID:1, PID:3][...]-------------------->|
   |<------------------[CID:1, PID:3][...]---------------------| 3
   |<------------------[CID:1, PID:4][...]---------------------| 4
   |<------------------[CID:1, PID:5][...]---------------------| 5
 4 |-------------------[CID:1, PID:4][...]-------------------->|
   |                                                           |
   v                                                           v
~~~~
{: title="Sequence diagram of packet ID incrementation" }

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
for flexible state exchange, and also provide the means for multistreaming,
both discussed in detail in the following section.

# Communication Structure {#communication-structure}

TCP's rigid header structure has made it difficult to extend the protocol
to more modern requirements. RFT as a file transfer protocol may be more
specialized but still requires flexibility to fit different scenarios.
For the transfer of a single large file not much is needed, but synchronizing
directories consisting of many small files calls for parallelization which
can introduce new challenges like head-of-line blocking or state complexity.

In general, the ideal way to handle the transfers depend on the specific
nature of the application. Therefore RFT tries to provide a flexible
framework for issuing file transfers, related actions and handling their
responses. The application layer can then decide how to use these mechanisms
and how much parallelization and complexity it requires.

RFT achieves said flexibility by adopting two structural ideas from QUIC
{{RFC9000}}, frames and streams. How these are used in RFT is discussed in
the following subsections.

## Frames {#frames}

Frames subdivide packets into the atomic units of state exchange of the
protocol. All frames have in common that they start with an 8 bit type ID.
The ExitFrame for closing the connection is the only frame, that consists of
nothing but the type ID 1:

~~~~ language-REPLACE/DELETE
ExitFrame (8) {
  U8  TypeId = 1,
}
~~~~
{: title="Exit frame wire format" }

For frames with only header fields the length is implicitly given. Frames
with variably sized path, message, or payload fields have a length field
right in front of them. File data for example is carried in DataFrames:

~~~~ language-REPLACE/DELETE
DataFrame (72 + len(Payload)) {
  U8     TypeId = 6,
  U16    StreamId,
  U48    Offset,
  Bytes  Payload,
}
~~~~
{: title="Data frame wire format" }

The order of frames in a packet is only relevant within the same stream,
the concept discussed in the following.

## Streams {#streams}

Streams are logical channels within the connection encapsulating the frames
belonging to a particular operation. This enables the parallel execution of
multiple file transfers for example. Such frames carry a 16-bit stream ID
(SID) to identify the stream they belong to. At any time there CANNOT be
more than one stream with the same ID within the connection. Stream IDs MAY
however be reused after completion of a previous stream with that ID.

A stream is created by the client when sending a command frame
to the server. The stream ID is not negotiated but chosen by the client
and send to the server in the command frame, for example in the ReadFrame:

~~~~ language-REPLACE/DELETE
ReadFrame (160 + len(Path)) {
  U8      TypeId = 7,
  U16     StreamId,
  U7      Reserved = 0,
  Bool    ValidateChecksum,
  U48     Offset,
  U48     Length,
  U32     Checksum,
  String  Path,
}
~~~~
{: title="Read frame wire format" }

The client is therefore solely responsible for ensuring the time-local
uniqueness of the stream ID. The server MUST answer commands with the same
stream ID and in the context of the same stream.

Streams are closed when either the requested operation is completed,
via an AnswerFrame or an empty DataFrame which signals EOF for transfers,
or with an ErrorFrame in conflict cases.

Frames for connection global control traffic like AckFrames or FlowFrames
do not carry a stream ID and are implicitly associated to the virtual stream 0.
This stream ID MUST NOT be used for any other purpose.

The following sequence diagram shows the parallel execution of a read and stat
command using two different streams (SID 1 and 2) on the same connection,
ignoring acknowledgements:

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |--------[CID:1, PID:5][READ, SID:1, PATH:hello.md]-------->|
   |                                                           |
   |<----------[CID:1, PID:4][DATA, SID:1, LEN:1000]-----------|
   |<----------[CID:1, PID:5][DATA, SID:1, LEN:1000]-----------|
   |                                                           |
   |---------[CID:1, PID:6][STAT, SID:2, PATH:test.md]-------->|
   |                                                           |
   |<----[CID:1, PID:6][DATA, SID:1, LEN:100][EOF, SID:1]------|
   |                   [ANSWER, SID:2, stat data...]           |
   |                                                           |
   v                                                           v
~~~~
{: title="Simplified sequence diagram of read and stat commands executed
in parallel, ignoring acknowledgements. Note the different stream IDs." }

Both streams are terminated in the same packet, one with the EOF (empty
DataFrame) and the other with an AnswerFrame.

In contrast the following example shows how the server returns an error
in case of a duplicate stream ID:

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |--------[CID:1, PID:5][READ, SID:1, PATH:hello.md]-------->|
   |                                                           |
   |<----------[CID:1, PID:4][DATA, SID:1, LEN:1000]-----------|
   |<----------[CID:1, PID:5][DATA, SID:1, LEN:1000]-----------|
   |                                                           |
   |---------[CID:1, PID:6][STAT, SID:1, PATH:test.md]-------->|
   |                                                           |
   |<----[CID:1, PID:6][ERROR, SID:1, MSG:"Duplicate SID"]-----|
   |                                                           |
   v                                                           v
~~~~
{: title="Simplified sequence diagram of an error due to duplicate stream ID" }

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
   |----------------------[CID:0, PID:1]---------------------->|
   |                                                           |
   |<---------------[CID:1, PID:1][ACK, PID:1]-----------------|
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
   |-----------[CID:0, PID:1][CHCID, OLD:0, NEW:3]------------>|
   |                                                           |
   |<---------------[CID:3, PID:1][ACK, PID:1]-----------------|
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
   |-----------[CID:0, PID:1][CHCID, OLD:0, NEW:3]------------>|
   |                                                           |
   |<-----[CID:3, PID:1][ACK, PID:1][CHCID, OLD:3, NEW:9]------|
   |                                                           |
   |-----------------[CID:9, PID:2][ACK, PID:1]--------------->|
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
   |------------------[CID:5, PID:125][EXIT]------------------>|
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
offset and length fields in the Read- and WriteFrames.

# Robustness {#robustness}

The protocol has multiple mechanisms to ensure transmissions are complete,
in-order and integrity is maintained, while not overwhelming the receiver
or the network. It takes inspiration from both QUIC {{RFC9000}} and TCP
{{RFC0768}}.

## In-Order Delivery {#in-order-delivery}

The [Packet ID](#packet-id) is a monotonically increasing counter for the packets send
by a peer. It thus allows the receiving side to determine the order in which
packets were sent out. Streams do not have a separate ordering mechanism, so
implementations are REQUIRED to process frames only after all previous packets
and thus frames have been completely handled. An implementation SHOULD be able
to buffer packets for a short time within limits of a timeout to counteract
reordering that might have occurred in the network before requesting
retransmissions.

## Acknowledgements {#acknowledgements}

To ensure completeness the receiver acknowledges packets via AckFrames:

~~~~ language-REPLACE/DELETE
AckFrame (40) {
  U8   TypeId = 0,
  U32  PacketId,
}
~~~~
{: title="Acknowledgement frame wire format" }

It contains the last consecutively received packet ID and thus acknowledges
all packets up to that point cumulatively:

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |<------[CID:3, PID:10][DATA, SID:2, OFF:0, LEN:1000]-------|
   |<-----[CID:3, PID:11][DATA, SID:2, OFF:1000, LEN:1000]-----|
   |<-----[CID:3, PID:12][DATA, SID:2, OFF:2000, LEN:1000]-----|
   |                                                           |
   |----------------[CID:3, PID:4][ACK, PID:12]--------------->|
   |                                                           |
   v                                                           v
~~~~
{: title="Example sequence diagram of cumulative acknowledgement" }

Empty packets or those with only an AckFrame do NOT NEED to be acknowledged
to prevent an acknowledgment loop.

## Retransmission {#retransmission}

There are two ways retransmissions are triggered.

### Retransmission Timeout {#retransmission-timeout}
If sender does not receive an AckFrame for a packet or a later one
within the retransmission timeout (RTO) of 1 second a normal
retransmission (RT) is triggered:

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |   X---[CID:3, PID:10][DATA, SID:2, OFF:0, LEN:1000]-------| 0s
   |   X--[CID:3, PID:11][DATA, SID:2, OFF:1000, LEN:1000]-----|
   |<-----[CID:3, PID:12][DATA, SID:2, OFF:2000, LEN:1000]-----|
   |<-----[CID:3, PID:13][DATA, SID:2, OFF:3000, LEN:1000]-----|
   |<-----[CID:3, PID:14][DATA, SID:2, OFF:4000, LEN:1000]-----| RTO
   |                                                           |
   |<------[CID:3, PID:10][DATA, SID:2, OFF:0, LEN:1000]-------| RT
   |<-----[CID:3, PID:11][DATA, SID:2, OFF:1000, LEN:1000]-----|
   |<-----[CID:3, PID:12][DATA, SID:2, OFF:2000, LEN:1000]-----|
   |                                                           |
   |----------------[CID:3, PID:4][ACK, PID:12]--------------->| ACK
   |                           ...                             |
   |                                                           |
   v                                                           v
~~~~
{: title="Example sequence diagram of retransmission (RT)" }

### Fast Retransmission {#fast-retransmission}

The receiver can also request a fast retransmission (FRT)
by sending a duplicate AckFrame (DACK) for the last packet it received:

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
   |                                                           |
   |<------[CID:3, PID:10][DATA, SID:2, OFF:0, LEN:1000]-------| 0s
   |   X--[CID:3, PID:11][DATA, SID:2, OFF:1000, LEN:1000]-----| LOSS
   |   X--[CID:3, PID:12][DATA, SID:2, OFF:2000, LEN:1000]-----|
   |<-----[CID:3, PID:13][DATA, SID:2, OFF:3000, LEN:1000]-----|
   |                                                           |
   |---------[CID:3, PID:4][ACK, PID:10][ACK, PID:10]--------->| DACK
   |                                                           |
   |<------[CID:3, PID:10][DATA, SID:2, OFF:1000, LEN:1000]----| FRT
   |<------[CID:3, PID:11][DATA, SID:2, OFF:2000, LEN:1000]----|
   |                           ...                             |
   |                                                           |
   v                                                           v
~~~~
{: title="Example sequence diagram of fast retransmission (FRT)" }

## Congestion Control {#congestion-control}

Congestion control is inspired by TCP's AIMD {{RFC0768}}.
A congestion window (CWND) limits the amount of bytes in-flight.
The window scaling goes through two phases:

### Slow Start

The congestion window starts at 1 and is updated for each packet
containing an AckFrame as "CWND_NEW = min(2 * CWND, FWND)" with FWND being
the window indicated by flow control, and ends once the slow start threshold
is reached.

### Congestion Avoidance

After the slow start the AIMD (additive increase, multiplicative decrease)
algorithm is used. The congestion window is increased by one for each
acknowledged packet. In case a retransmission is necessary congestion is
assumed and the congestion window is halved and avoidance continues from there.
A timeout causes a reset of the congestion window to one and continues with a
slow start where the threshold set to half the number of packets in-flight.

## Flow Control {#flow-control}

To avoid overwhelming the receiver it indicates its available receive buffer
size for flow window (FWND) via FlowControl frames:

~~~~ language-REPLACE/DELETE
FlowControl (40) {
  U8   TypeId = 3,
  U32  WindowSize,
}
~~~~
{: title="Flow control frame wire format" }

The window size is the number of bytes left in the receive buffer.
When a sender receives this frame it MUST NOT exceed the indicated limit.
The following example shows how the peer SHOULD react:

~~~~ LANGUAGE-REPLACE/DELETE
   Client                                                     Server
     |                                                           |
FWND |                                                           |
---- |                                                           |
4500 |<------[CID:3, PID:10][DATA, SID:2, OFF:0, LEN:1000]-------|
3500 |<-----[CID:3, PID:11][DATA, SID:2, OFF:1000, LEN:1000]-----|
2500 |<-----[CID:3, PID:12][DATA, SID:2, OFF:2000, LEN:1000]-----|
1500 |<-----[CID:3, PID:13][DATA, SID:2, OFF:3000, LEN:1000]-----|
     |                                                           |
     |--------[CID:3, PID:4][ACK, PID:13][FLOW, WND:1500]------->|
     |                                                           |
1000 |<-----[CID:3, PID:14][DATA, SID:2, OFF:4000, LEN:500]------|
 500 |<-----[CID:3, PID:15][DATA, SID:2, OFF:4500, LEN:500]------|
     |                           ...                             |
     |                                                           |
     v                                                           v
~~~~
{: title = "Example sequence diagram of fast retransmission (FRT)" }

## Checksumming {#checksumming}

For the integrity validation of the transmission the partial CRC32 checksum
in the packet header is used. Before processing a packet any further the
receiver MUST verify that the checksum calculated over the remaining packet
matches the one in the header. If it does not the packet MUST be discarded
as not even the connection or packet IDs that are required to issue a
fast retransmission can be trusted. The receiver has to wait for a timeout
to trigger retransmission on the sender side.

# File Transfer {#file-transfer}

File transfers in either direction are initiated by the client via the
respective command (read or write) frames send on a new stream. Following that
data and acknowledgement frames are exchanged until the transfer is complete,
indicated by an empty end-of-file (EOF) data frame.

Both read and write frames indicate the path of the file together with the
offset and length to be transferred. An offset of 0 indicates starting at the
beginning of the file, a length of 0 indicates transferring everything from
the offset up to the end of the file.

## Read {#read}

To read a file from the server the client sends a ReadFrame:

~~~~ language-REPLACE/DELETE
ReadFrame (160 + len(Path)) {
  U8      TypeId = 7,
  U16     StreamId,
  U7      Reserved = 0,
  Bool    ValidateChecksum,
  U48     Offset,
  U48     Length,
  U32     Checksum,
  String  Path,
}
~~~~
{: title="Read frame wire format" }

In case of reading an entire file the frame could look like this:

~~~~ language-REPLACE/DELETE
ReadFrame {
  TypeId            = 7,
  StreamId          = 1,
  Reserved          = 0,
  ValidateChecksum  = false,
  Offset            = 0,
  Length            = 0,
  Checksum          = 0,
  Path              = "./example/README.md",
}
~~~~
{: title="Example read frame" }

The following sequence diagram puts such frame into context
(Note that we omit fields that are not relevant for the example):

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
|                                                                 |
|----[CID:3, PID:4][READ, SID:5, OFF:0, LEN:0, PATH:readme.md]--->|
|                                                                 |
|<---[CID:3, PID:10][ACK, PID:4][DATA, SID:5, OFF:0, LEN:1000]----|
|<--------[CID:3, PID:11][DATA, SID:5, OFF:1000, LEN:1000]--------|
|<--------[CID:3, PID:12][DATA, SID:5, OFF:2000, LEN:1000]--------|
|                                                                 |
|-------------------[CID:3, PID:5][ACK, PID:12]------------------>|
|                                                                 |
|<--------[CID:3, PID:13][DATA, SID:5, OFF:3000, LEN:1000]--------|
|                        [ACK, PID:5]                             |
|<--------[CID:3, PID:14][DATA, SID:5, OFF:4000, LEN:177]---------|
|                        [DATA, SID:5, OFF:4178, LEN:0]           |
|                                                                 |
|------------------[CID:3, PID:6][ACK, PID:14]------------------->|
|                                                                 |
v                                                                 v
~~~~
{: title="Sequence diagram for an example file read" }

Aside from the already discussed fields the ReadFrame also contains a
boolean ValidateChecksum flag together with the optional Checksum field.
These allow the client to ensure that the already read portion is still the
same before continuing to read it. When the client sets the ValidateChecksum
flag to true, it MUST provide the CRC32 checksum of the already read portion
and set the offset to the byte after that part. The server MUST then validate
that the checksum matches for the file on its end and continue reading if it
does. If the checksum does not match the server MUST back an ErrorFrame with
a message "Checksum mismatch".

## Write {#write}

To write a file on the server the client sends a WriteFrame:

~~~~ language-REPLACE/DELETE
WriteFrame (120 + len(Path)) {
  U8      TypeId = 8,
  U16     StreamId,
  U48     Offset,
  U48     Length,
  String  Path,
}
~~~~
{: title="Example write frame" }

In case of writing a file without specifying its size ahead of time the
frame could look like this:

~~~~ language-REPLACE/DELETE
WriteFrame {
  TypeId    = 8,
  StreamId  = 1,
  Offset    = 0,
  Length    = 0,
  Path      = "./example/README.md",
}
~~~~
{: title="Example write frame" }

The following sequence diagram puts such frame into context
(Note that we omit fields that are not relevant for the example):

~~~~ LANGUAGE-REPLACE/DELETE
Client                                                       Server
|                                                                 |
|---[CID:3, PID:4][WRITE, SID:5, OFF:0, LEN:0, PATH:readme.md]--->|
|                 [DATA, SID:5, OFF:0, LEN:1000]                  |
|---------[CID:3, PID:5][DATA, SID:5, OFF:1000, LEN:1000]-------->|
|---------[CID:3, PID:6][DATA, SID:5, OFF:2000, LEN:1000]-------->|
|                                                                 |
|<------------------[CID:3, PID:5][ACK, PID:6]--------------------|
|                                                                 |
|---------[CID:3, PID:7][DATA, SID:5, OFF:3000, LEN:1000]-------->|
|                       [ACK, PID:5]                              |
|---------[CID:3, PID:8][DATA, SID:5, OFF:4000, LEN:177]--------->|
|                       [DATA, SID:5, OFF:4178, LEN:0]            |
|                                                                 |
|<------------------[CID:3, PID:6][ACK, PID:8]--------------------|
|                                                                 |
v                                                                 v
~~~~
{: title="Sequence diagram for an example file write" }

WriteFrames do not contain a checksum field that requires any special handling.

## Multiple Transfers {#multiple-transfers}

TODO

## Recovery

TODO

# Further Commands {#further-commands}

TODO

# Wire Format {#wire-format}

TODO

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
PacketHeader (96) {
  U8   Version = 1,
  U32  ConnectionId,
  U32  PacketId,
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
AckFrame (40) {
  U8   TypeId = 0,
  U32  PacketId,
}
~~~~
{: title="Acknowledgement frame wire format" }

~~~~ language-REPLACE/DELETE
ExitFrame (8) {
  U8  TypeId = 1,
}
~~~~
{: title="Exit frame wire format" }

~~~~ language-REPLACE/DELETE
ConnIdChange (72) {
  U8   TypeId = 2,
  U32  OldConnId,
  U32  NewConnId,
}
~~~~
{: title="Connection ID Change frame wire format" }

~~~~ language-REPLACE/DELETE
FlowControl (40) {
  U8   TypeId = 3,
  U32  WindowSize,
}
~~~~
{: title="Flow control frame wire format" }

~~~~ language-REPLACE/DELETE
AnswerFrame (24 + len(Payload)) {
  U8     TypeId = 4,
  U16    StreamId,
  Bytes  Payload,
}
~~~~
{: title="Answer frame wire format" }

~~~~ language-REPLACE/DELETE
ErrorFrame (24 + len(Message)) {
  U8      TypeId = 5,
  U16     StreamId,
  String  Message,
}
~~~~
{: title="Error frame wire format" }

~~~~ language-REPLACE/DELETE
DataFrame (72 + len(Payload)) {
  U8     TypeId = 6,
  U16    StreamId,
  U48    Offset,
  Bytes  Payload,
}
~~~~
{: title="Data frame wire format" }

~~~~ language-REPLACE/DELETE
ReadFrame (160 + len(Path)) {
  U8      TypeId = 7,
  U16     StreamId,
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
WriteFrame (120 + len(Path)) {
  U8      TypeId = 8,
  U16     StreamId,
  U48     Offset,
  U48     Length,
  String  Path,
}
~~~~
{: title="Write frame wire format" }

~~~~ language-REPLACE/DELETE
ChecksumFrame (24 + len(Path)) {
  U8      TypeId = 9,
  U16     StreamId,
  String  Path,
}
~~~~
{: title="Checksum frame wire format" }

~~~~ language-REPLACE/DELETE
StatFrame (24 + len(Path)) {
  U8      TypeId = 10,
  U16     StreamId,
  String  Path,
}
~~~~
{: title="Stat frame wire format" }

~~~~ language-REPLACE/DELETE
ListFrame (24 + len(Path)) {
  U8      TypeId = 11,
  U16     StreamId,
  String  Path,
}
~~~~
{: title="List frame wire format" }

~~~~ language-REPLACE/DELETE
Path (2 + Length) {
  U16           Length,
  Char[Length]  Buffer,
}
~~~~
{: title="Path wire format" }

~~~~ language-REPLACE/DELETE
String (2 + Length) {
  U16           Length,
  Char[Length]  Buffer,
}
~~~~
{: title="String wire format" }

~~~~ language-REPLACE/DELETE
Bytes (2 + Length) {
  U16         Length,
  U8[Length]  Buffer,
}
~~~~
{: title="Bytes wire format" }
