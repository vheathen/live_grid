# LiveGrid

It's an educational project: an interprocess communication and message routing example.

The main idea is to start any number of processes where each process has name as a coordinate
of a grid cell (like `{1, 2}` or `{5, 192}`). Each process can reach only its direct neighbors:

```
{0, 1}     {0, 2}     {0, 3}
{1, 1}   <<{1, 2}>>   {1, 3}
{2, 1}     {2, 2}     {2, 3}
```

On every grid configuration change (grid node started or shutdowned) route updates must issued.

Then any grid node can be able to send a message to any other grid node and it should be delivered through
the grid if continuous routing exists.

It's not finished yet, but processes can be started and can exchange routing information.