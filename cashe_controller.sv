`timescale 1ns/1ps

module cache_controller(
    input  logic        clk,
    input  logic        reset,

    input  logic        cpu_read,
    input  logic        cpu_write,
    input  logic [31:0] cpu_addr,
    input  logic [31:0] cpu_wdata,

    output logic [31:0] cpu_rdata,
    output logic        cpu_ready
);

parameter SETS = 4;
parameter WAYS = 4;


// Cache Arrays

logic [31:0] cache_data [0:SETS-1][0:WAYS-1];
logic [27:0] cache_tag  [0:SETS-1][0:WAYS-1];

logic valid [0:SETS-1][0:WAYS-1];
logic dirty [0:SETS-1][0:WAYS-1];

logic [1:0] lru [0:SETS-1][0:WAYS-1];


// Address decomposition


logic [1:0]  set_index;
logic [27:0] tag;

assign set_index = cpu_addr[3:2];
assign tag       = cpu_addr[31:4];


// Hit logic


logic hit;
logic [1:0] hit_way;

always_comb begin
    int way;

    hit = 0;
    hit_way = 0;

    for(way=0; way<WAYS; way=way+1)
    begin
        if(valid[set_index][way] &&
           cache_tag[set_index][way] == tag)
        begin
            hit = 1;
            hit_way = way[1:0];
        end
    end
end


// Replacement selection


logic [1:0] replace_way;

always_comb begin
    int way;

    if(!valid[set_index][0])
        replace_way = 0;
    else if(!valid[set_index][1])
        replace_way = 1;
    else if(!valid[set_index][2])
        replace_way = 2;
    else if(!valid[set_index][3])
        replace_way = 3;
    else
    begin
        replace_way = 0;

        for(way=1; way<WAYS; way=way+1)
        begin
            if(lru[set_index][way] >
               lru[set_index][replace_way])
                replace_way = way[1:0];
        end
    end
end


// Saved CPU Request


logic [31:0] saved_addr;
logic [31:0] saved_wdata;

logic saved_read;
logic saved_write;

logic [1:0]  saved_set;
logic [27:0] saved_tag;
logic [1:0]  saved_way;


// Memory Interface


logic        mem_read;
logic        mem_write;

logic [31:0] mem_addr;
logic [31:0] mem_wdata;

logic [31:0] mem_rdata;
logic        mem_ready;

main_memory MEM(
    .clk(clk),
    .reset(reset),

    .read_req(mem_read),
    .write_req(mem_write),

    .addr(mem_addr),
    .write_data(mem_wdata),

    .read_data(mem_rdata),
    .ready(mem_ready)
);


// FSM States


typedef enum logic [1:0]
{
    IDLE,
    WRITE_BACK,
    ALLOCATE
} state_t;

state_t state;


// LRU update on hit


task automatic update_lru_hit(
    input logic [1:0] set,
    input logic [1:0] accessed_way
);

    integer k;
    logic [1:0] old_rank;

begin
    old_rank = lru[set][accessed_way];

    for(k=0;k<WAYS;k=k+1)
    begin
        if(k != accessed_way)
        begin
            if(lru[set][k] < old_rank)
                lru[set][k] <= lru[set][k] + 1;
        end
    end

    lru[set][accessed_way] <= 0;
end
endtask


// LRU update on fill

task automatic update_lru_fill(
    input logic [1:0] set,
    input logic [1:0] filled_way
);

    integer k;

begin
    for(k=0;k<WAYS;k=k+1)
    begin
        if(k != filled_way)
        begin
            if(valid[set][k] && lru[set][k] < 3)
                lru[set][k] <= lru[set][k] + 1;
        end
    end

    lru[set][filled_way] <= 0;
end
endtask


// Main FSM

always_ff @(posedge clk)
begin
    integer s,w;

    if(reset)
    begin
        for(s=0;s<SETS;s=s+1)
        begin
            for(w=0;w<WAYS;w=w+1)
            begin
                cache_data[s][w] <= 0;
                cache_tag[s][w]  <= 0;

                valid[s][w] <= 0;
                dirty[s][w] <= 0;

                lru[s][w] <= w[1:0];
            end
        end

        saved_addr  <= 0;
        saved_wdata <= 0;

        saved_read  <= 0;
        saved_write <= 0;

        saved_set   <= 0;
        saved_tag   <= 0;
        saved_way   <= 0;

        mem_read    <= 0;
        mem_write   <= 0;

        mem_addr    <= 0;
        mem_wdata   <= 0;

        cpu_ready   <= 0;
        cpu_rdata   <= 0;

        state <= IDLE;
    end
    else
    begin
        cpu_ready <= 0;

        case(state)

        IDLE:
        begin
            mem_read  <= 0;
            mem_write <= 0;

            if(cpu_read || cpu_write)
            begin
                if(hit)
                begin
                    if(cpu_read)
                        cpu_rdata <= cache_data[set_index][hit_way];

                    if(cpu_write)
                    begin
                        cache_data[set_index][hit_way] <= cpu_wdata;
                        dirty[set_index][hit_way] <= 1;
                    end

                    update_lru_hit(set_index, hit_way);

                    cpu_ready <= 1;
                end
                else
                begin
                    saved_addr  <= cpu_addr;
                    saved_wdata <= cpu_wdata;

                    saved_read  <= cpu_read;
                    saved_write <= cpu_write;

                    saved_set   <= set_index;
                    saved_tag   <= tag;
                    saved_way   <= replace_way;

                    if(valid[set_index][replace_way] &&
                       dirty[set_index][replace_way])
                    begin
                        mem_write <= 1;

                        mem_addr <= {
                            cache_tag[set_index][replace_way],
                            set_index,
                            2'b00
                        };

                        mem_wdata <=
                            cache_data[set_index][replace_way];

                        state <= WRITE_BACK;
                    end
                    else
                    begin
                        mem_read <= 1;

                        mem_addr <= {
                            cpu_addr[31:2],
                            2'b00
                        };

                        state <= ALLOCATE;
                    end
                end
            end
        end

        WRITE_BACK:
        begin
            mem_write <= 0;

            if(mem_ready)
            begin
                mem_read <= 1;

                mem_addr <= {
                    saved_addr[31:2],
                    2'b00
                };

                state <= ALLOCATE;
            end
        end

        ALLOCATE:
        begin
            mem_read <= 0;

            if(mem_ready)
            begin
                cache_tag[saved_set][saved_way] <= saved_tag;
                valid[saved_set][saved_way] <= 1;

                if(saved_read)
                begin
                    cache_data[saved_set][saved_way] <= mem_rdata;
                    dirty[saved_set][saved_way] <= 0;
                    cpu_rdata <= mem_rdata;
                end

                if(saved_write)
                begin
                    cache_data[saved_set][saved_way] <= saved_wdata;
                    dirty[saved_set][saved_way] <= 1;
                end

                update_lru_fill(saved_set, saved_way);

                cpu_ready <= 1;
                state <= IDLE;
            end
        end

        default:
            state <= IDLE;

        endcase
    end
end

endmodule
