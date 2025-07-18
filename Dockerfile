FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Create non-root user
RUN useradd -m -u 10000 simulator && chown -R simulator:simulator /app
USER simulator

# Set default command
CMD ["python", "eventhub_simulator.py", "--help"]
