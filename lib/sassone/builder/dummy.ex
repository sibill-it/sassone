defmodule Sassone.Builder.Dummy do
  defstruct []
end

defimpl Sassone.Builder, for: Sassone.Builder.Dummy do
  def attributes(_t), do: []
  def elements(_t), do: []
  def namespace(_t), do: nil
  def handler(_t), do: nil
  def root_element(_t), do: nil
end
