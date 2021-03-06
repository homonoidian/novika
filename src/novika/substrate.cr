module Novika
  # Substrate is a fast, low-level copy-on-write wrapper for
  # an array.
  module Substrate(T)
    # Initializes an empty substrate.
    def self.[]
      RealSubstrate(T).new
    end

    # Initializes a substrate with *elements*.
    def self.[](*elements)
      RealSubstrate.new(elements.to_a)
    end

    # Same as `Array#each`.
    delegate :each, to: array

    # Unsafely fetches the element at *index*.
    def at!(index)
      array.unsafe_fetch(index)
    end

    # Returns the amount of elements in the array.
    def count
      array.size
    end

    # Returns the element at *index*. Returns nil if *index* is
    # out of bounds, i.e., *not* in `0 <= index < count`.
    def at?(index)
      at!(index) if index.in?(0...count)
    end

    # Returns the actual array.
    protected abstract def array

    # Overrides the element at *index* with *element*. Returns
    # nil if *index* is out of bounds (see `at?`).
    abstract def set?(at index, element)

    # Adds *element* before *index*. Returns nil if *index* is
    # out of bounds (see  `at?`).
    abstract def insert?(at index, element)

    # Deletes the element at *index*. Returns nil if *index* is
    # out of bounds (see `at?`).
    abstract def delete?(at index)

    # Decrements the amount of references to this substrate.
    abstract def deref

    # Returns a copy of this substrate.
    abstract def copy

    def_equals_and_hash array
  end

  # Operates on an existing substrate array, not under its
  # control. "Becomes" `RealSubstrate`  with shallow copy of
  # the array upon the first mutatation.
  private struct RefSubstrate(T)
    include Substrate(T)

    protected getter res : RealSubstrate(T)

    def initialize(@res : RealSubstrate(T) = RealSubstrate(T).new)
      res.refs += 1
    end

    protected delegate :array, to: res

    # Makes a copy of the referenced substrate, and calls this
    # method on it.
    delegate :set?, :insert?, :delete?, to: begin
      res.refs -= 1

      RealSubstrate.new(array.dup)
    end

    def deref
      res.refs -= 1
    end

    def copy
      RefSubstrate.new(res)
    end
  end

  # Real substrate: operates on a substrate array under its
  # control. Copying returns a `RefSubstrate`.
  private class RealSubstrate(T)
    include Substrate(T)

    protected getter array : Array(T)

    # Returns/allows to set the amount of references to this
    # substrate.
    protected property refs = 0

    protected def initialize(@array : Array(T) = [] of T)
    end

    # Introduces a mutation.
    #
    # If reference count is non-zero (someone watches us), a
    # copy is made and is modified. If reference count is zero
    # (no one watches us), this object is modified.
    protected def mutate
      object = refs.zero? ? self : RealSubstrate.new(array.dup)
      object.tap { yield object }
    end

    def set?(at index, element)
      mutate &.array.unsafe_set(index, element) if index.in?(0...count)
    end

    def insert?(at index, element)
      mutate &.array.insert(index, element) if index.in?(0..count)
    end

    def delete?(at index)
      mutate &.array.delete_at(index) if index.in?(0..count)
    end

    def deref
      self.refs -= 1
    end

    def copy
      RefSubstrate.new(self)
    end
  end
end
