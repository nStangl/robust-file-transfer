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

Robust File Transfer (RFT) is a file-transfer protocol on top of UDP.
It is connection-oriented, stream-parallel and stateful, supporting connection migration based on connection IDs similar to QUIC.
RFT provides point-to-point operation between a client and a server, enabling IP address migration, flow control, congestion control, and partial or resumed file transfers using offsets and lengths.

--- middle

# Introduction {#introduction}

The Protocol Design WG is tasked with standardizing an Application Protocol for a robust file transfer protocol, RFT.
This protocol is intended to provide point-to-point operation between a client and a server built upon UDP {{RFC0768}}.
It supports connection migration based on connection IDs, in spirit similar to QUIC {{RFC9000}}, although a bit easier.

RFT is based on UDP, connection-oriented, stateful and uses streams for each file transfer
allowing for parallelization.
A point-to-point connection supports IP address migration, flow control, congestion control and allows to transfers of a specific length and offset, which can be useful to resume interrupted transfers or partial transfers.
The protocol guarantees in-order delivery for all packets belonging to a stream.
There is no such guarantee for messages belonging to different streams.

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

This document defines `U4`, `U8`, `U16`, `U32`, `U64` as unsigned 4-, 8-, 16-, 32-, or 64-bit integers.
A `string` is a UTF-8 {{RFC3629}} encoded zero-terminated string.

Messages are represented in a C struct-like notation. They may be annotated by C-style comments.
All members are laid out continuously on wire, any padding will be made explicit.
Constant values are assigned with a "=".

~~~~ LANGUAGE-REPLACE/DELETE
StructName1 (Length) {
    TypeName1     FieldName1,
    TypeName2     FieldName2,
    TypeName3[4]  FieldName3,
    String        FieldName4,
    StructName2   FieldName5,
}
~~~~
{: title='Message format notation' }

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
{: title='Sequence diagram notation' }

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
