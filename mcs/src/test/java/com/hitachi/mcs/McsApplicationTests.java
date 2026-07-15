package com.hitachi.mcs;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import com.hitachi.mcs.kafka.TransactionEventProducer;

@SpringBootTest
@ActiveProfiles("test")
class McsApplicationTests {

	@MockitoBean
	private TransactionEventProducer transactionEventProducer;

	@Test
	void contextLoads() {
	}

}
