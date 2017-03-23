defmodule Insightdb.Mock do

  def gen_and_replace({m, opts, fns}, key, new_fn) do
    new_fns = if Keyword.has_key?(fns, key) do
      Keyword.put(fns, key, new_fn)
    else
      Keyword.put_new(fns, key, new_fn)
    end
    {m, opts, new_fns}
  end

end
