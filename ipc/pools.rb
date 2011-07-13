
class Pools < Ipc 
  attr :session, true
  attr :client, true

  def initialize(session = nil, client = nil)
    @session = session
    @client = client
    @ipc = 'jsplasma-ipc'
  end

  def isMine(protein)
    protein.hose.pool_name =~ /#{@ipc}/
  end

  def get
    begin
      @handle = Hose.new @ipc
    rescue
      Pool.create @ipc
      @handle = Hose.new @ipc
    end
    @handle
  end

  def put(oper, param2=nil)
    if param2.nil?
      get.deposit Protein.new([
          @client,
          @session
        ],
        Slaw.new(oper, :map)
      )
    else
      get.deposit Protein.new([
          @client,
          @session
        ],
        Slaw.new({
          'data' => oper,
          'action' => param2
        }, :map)
      )
    end

    @handle.withdraw
  end

  def error(type, data)
    put({
      'action' => 'error',
      'type' => type,
      'data' => data
    })
  end

end
