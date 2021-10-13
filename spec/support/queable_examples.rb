shared_examples "queable" do
  describe "#add" do
    it "pushs object to array" do
      instance = described_class.new
      object = {
        hello: :world,
      }

      instance.add(object)

      expect(instance.instance_variable_get(:@queue)).
        to eq([object])
    end

    context "when already have elements" do
      it "pushes element to the end" do
        instance = described_class.new
        object1 = {
          hello: :world,
        }
        object2 = {
          fizz: :buzz,
        }

        instance.add(object1)
        instance.add(object2)

        expect(instance.instance_variable_get(:@queue).last).
          to eq(object2)
      end
    end
  end

  describe "#each" do
    it "returns elements in reverse order" do
      instance = described_class.new
      object1 = {
        hello: :world,
      }
      object2 = {
        fizz: :buzz,
      }

      instance.instance_variable_set(
        :@queue,
        [object1, object2],
      )

      result = []
      instance.each { |el| result.push(el) }

      expect(result).to eq([object2, object1])
    end
  end

  describe "#pop" do
    it "returns last element and removes it from queue" do
      instance = described_class.new
      object1 = {
        hello: :world,
      }
      object2 = {
        fizz: :buzz,
      }

      instance.instance_variable_set(
        :@queue,
        [object1, object2],
      )

      result = instance.pop

      expect(result).to eq(object2)
      expect(instance.instance_variable_get(:@queue)).
        to eq([object1])
    end
  end
end
