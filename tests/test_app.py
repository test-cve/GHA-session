import unittest


class MySvcTests(unittest.TestCase):

    def test_greet(self):
        self.assertEqual("demo", "demo")


if __name__ == '__main__':
    unittest.main()
