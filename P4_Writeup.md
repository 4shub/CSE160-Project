1. The chat client and server application as described above uses a single transport connection in each direction per client. A different design would use a transport connection per command and reply. Describe the pros and cons of these two designs

2. Describe which features of your transport protocol are a good fit to the chat client and server applicati
on, and which are not. Are the features that are not a good fit simply unnecessary, or are they problematic, and why? If problematic, how can we best deal with them?

The transport protocol only can deal with strings, it would be better if we could send objects over the transport protocol so we could attach more data points to the protocol. We could write a function that parses an object to a string and then back into an object.

3. What extra credit?

4. Same as two, I would write a parser so I could pack more data into the protocol.

The way this works, essentially the chat clients all communicates to the server, which spits out context to the users. If we whisper, the server will send a message on behalf of another client to a client. We have a lookup map of all the users that we use to transmit data elsewhere.
