module Pwrake

  class Graphviz

    def initialize
      @nodes = {}
      @edges = []
      # @node_id = {}
      @filenode_id = {}
      @tasknode_id = {}
      @node_name = {}
      @count = 0
      @traced = {}

      @host2groupid = {}
      @count_gropuid = 1

      @depth_tag2id = {}
      @max_depth = 0
    end

    attr_reader :filenode_id, :tasknode_id, :node_name

    def trace( name = :default, target = nil )
      traced_cond = @traced[name]

      task = Rake.application[name]

      tn = nil
      fn = nil

      group_id = get_group_id(task)

      if task.kind_of?(Rake::FileTask)
        fn = push_filenode( name, group_id )
        if !task.actions.empty? and !traced_cond
          tn = push_tasknode( name, group_id )
          push_taskedge( name )
        end
        push_fileedge( name, target )
        target = name
      end
      @traced[name] = true

      if !traced_cond
        depth = 0
        task.prerequisites.each do |prereq|
          d = trace( prereq, target )
          depth = d if d and d > depth
        end
        if tn
          depth += 1
          @depth_tag2id[tn] = depth
          #puts "TASK:name=#{name} tn=#{tn} depth=#{depth}"
        end
        depth += 1
        @depth_tag2id[fn] = depth
      end

      depth = @depth_tag2id[fn]
      #puts "FILE:name=#{name} fn=#{fn} depth=#{depth}"
      @max_depth = depth if depth > @max_depth
      return depth
    end

    def get_group_id(task)
      host = task.locality[0]
      if host
        group_id = @host2groupid[host]
      else
        group_id = 0
      end
      if !group_id
        @host2groupid[host] = group_id = @count_gropuid
        @count_gropuid += 1
      end
      @nodes[group_id] ||= []
      return group_id
    end

    def get_host_id
      host = Thread.current[:connection].host
      return @host2groupid[host]
    end

    def get_gfwhere_id(filename)
      hash = Pwrake::GfarmSSH.gfwhere([filename])
      #host = hash[filename]
      host = hash.values[0][0]
      #p hash
      #p host
      return @host2groupid[host]
    end


    def trim( name )
      name = name.to_s
      name = File.basename(name)
      name.sub(/H\d+/,'').sub(/object\d+/,"")
    end

    def push_filenode( name, group )
      tag = @filenode_id[name]
      if tag.nil?
        tag = "T#{@count}"
        @count += 1
        @filenode_id[name] = tag
        @node_name[tag] = name
        @nodes[group].push [tag,"[label=\"#{trim(name)}\",shape=box];"]
      end
      return tag
    end

    def push_tasknode( name, group )
      tag = @tasknode_id[name]
      if tag.nil?
        tag = "T#{@count}"
        @count += 1
        @tasknode_id[name] = tag
        @node_name[tag] = name
        label = Rake.application[name].comment
        @nodes[group].push [tag,"[label=\"#{label}\",shape=ellipse];"]
      end
      return tag
    end

    def push_fileedge( name, target )
      if target
        if n2 = @tasknode_id[target]
          n1 = @filenode_id[name]
        elsif n1 = @tasknode_id[name]
          n2 = @filenode_id[target]
        else
          n1 = @filenode_id[name]
          n2 = @filenode_id[target]
        end
        @edges.push "#{n1} -> #{n2};"
      end
    end

    def push_taskedge( name )
      if n1 = @tasknode_id[name]
        n2 = @filenode_id[name]
        @edges.push "#{n1} -> #{n2};"
      end
    end

    def write(file)
      open(file, "w") do |w|
        #w.puts "digraph sample {\ngraph [size=\"12,100\",ranksep=1.5,nodesep=0.2];"
        w.puts "digraph sample {"
        w.puts "graph [size=\"70,70\",rankdir=LR,concentrate=true];"

        @nodes.each do |k,v|
          depth = Array.new(@max_depth){[]}
          if k>0
            w.puts "subgraph cluster#{k} {"
            w.puts "color=blue; style=bold; penwidth=10;"
          end
          v.each do |x|
            w.puts "#{x[0]} #{x[1]}"
            #puts "#{x[0]} #{x[1]} #{@depth_tag2id[x[0]]}"
            depth[@depth_tag2id[x[0]]].push x[0]
          end
          if k>0
            #range = 0..1
            range = 2..@max_depth
            ranks = range.map{|i| "R#{k}_#{i}"}
            ranks.each do |x|
              w.puts x+' [shape=plaintext,label="",fixedsize=true,width=0,height=0];'
            end
            w.puts ranks.join(" -> ")+' [arrowhead=none,penwidth=0,style=invis];'

            depth.each_with_index do |a,i|
              if range===i
                a.unshift ranks[i-range.first]
                w.puts "{rank=same;#{a.join(';')}}"
              end
            end

            w.puts "}"
          end
        end

        @edges.each do |x|
          w.puts x
        end
        w.puts "}"
      end
    end #write
  end
end
