import json
import unittest

from app import app


class MySvcTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.client = app.test_client()
        cls.client.testing = True

    def test_greet(self):
        name = "TestUser"
        response = self.client.get(f'/hello/{name}')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data.decode(), f"Hello, {name}!")

    def test_health_check(self):
        response = self.client.get('/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], "Healthy")
        self.assertEqual(data['message'], "The service is up and running!")
        self.assertIn('uptime', data)

        # Checks to ensure uptime is correctly calculated
        self.assertIn('days', data['uptime'])
        self.assertIn('hours', data['uptime'])
        self.assertIn('minutes', data['uptime'])
        self.assertIn('seconds', data['uptime'])


if __name__ == '__main__':
    unittest.main()
